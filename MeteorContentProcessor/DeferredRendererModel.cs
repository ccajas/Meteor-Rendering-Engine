using System;
using System.Collections.Generic;
using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Content.Pipeline;
using Microsoft.Xna.Framework.Content.Pipeline.Graphics;
using Microsoft.Xna.Framework.Content.Pipeline.Processors;

using TInput = System.String;
using TOutput = System.String;
using System.ComponentModel;
using System.IO;

namespace DeferredRenderingPipeline
{
    [ContentProcessor(DisplayName = "Deferred Renderer Model")]
    public class DeferredRendererModel : ModelProcessor
    {
        String directory;
        [DisplayName("Normal Map Texture")]
        [Description("If set, this file will be used as the normal map on the model, " +
        "overriding anything found in the opaque data.")]
        [DefaultValue("")]
        public string NormalMapTexture
        {
            get { return normalMapTexture; }
            set { normalMapTexture = value; }
        }
        private string normalMapTexture;

        [DisplayName("Normal Map Key")]
        [Description("This will be the key that will be used to search the normal map in the opaque data of the model")]
        [DefaultValue("NormalMap")]
        public string NormalMapKey
        {
            get { return normalMapKey; }
            set { normalMapKey = value; }
        }
        private string normalMapKey = "NormalMap";
        public override ModelContent Process(NodeContent input, ContentProcessorContext context)
        {
            if (input == null)
            {
                throw new ArgumentNullException("input");
            }
            directory = Path.GetDirectoryName(input.Identity.SourceFilename);
            LookUpTextures(input);
            return base.Process(input, context);
        }


        [Browsable(false)]
        public override bool GenerateTangentFrames
        {
            get { return true; }
            set { }
        }


        static IList<string> acceptableVertexChannelNames =
        new string[]
        {
            VertexChannelNames.TextureCoordinate(0),
            VertexChannelNames.Normal(0),
            VertexChannelNames.Binormal(0),
            VertexChannelNames.Tangent(0),
        };

        protected override void ProcessVertexChannel(GeometryContent geometry,
                                                    int vertexChannelIndex, ContentProcessorContext context)
        {
            String vertexChannelName =
                geometry.Vertices.Channels[vertexChannelIndex].Name;

            // if this vertex channel has an acceptable names, process it as normal.
            if (acceptableVertexChannelNames.Contains(vertexChannelName))
            {
                base.ProcessVertexChannel(geometry, vertexChannelIndex, context);
            }
            // otherwise, remove it from the vertex channels; it's just extra data
            // we don't need.
            else
            {
                geometry.Vertices.Channels.Remove(vertexChannelName);
            }
        }

        private void LookUpTextures(NodeContent node)
        {
            MeshContent mesh = node as MeshContent;
            if (mesh != null)
            {
                //this will contatin the path to the normal map texture
                string normalMapPath;

                //If the NormalMapTexture property is set, we use that normal map for all meshes in the model.
                //This overrides anything else
                if (!String.IsNullOrEmpty(NormalMapTexture))
                {
                    normalMapPath = NormalMapTexture;
                }
                else
                {
                    //If NormalMapTexture is not set, we look into the opaque data of the model, 
                    //and search for a texture with the key equal to NormalMapKey
                    normalMapPath = mesh.OpaqueData.GetValue<string>(NormalMapKey, null);
                }
                //if the NormalMapTexture Property was not used, and the key was not found in the model, than normalMapPath would have the value null.
                if (normalMapPath == null)
                {
                    //If a key with the required name is not found, we make a final attempt, 
                    //and search, in the same directory as the model, for a texture named 
                    //meshname_n.tga, where meshname is the name of a mesh inside the model.
                    normalMapPath = Path.Combine(directory, mesh.Name + "_n.tga");
                    if (!File.Exists(normalMapPath))
                    {
                        //if this fails also (that texture does not exist), 
                        //then we use a default texture, named null_normal.tga
                        normalMapPath = "null_normal.tga";
                    }
                }
                else
                {
                    normalMapPath = Path.Combine(directory, normalMapPath);
                }

                string specularMapPath;

                //If the SpecularMapTexture property is set, we use it
                if (!String.IsNullOrEmpty(SpecularMapTexture))
                {
                    specularMapPath = SpecularMapTexture;
                }
                else
                {
                    //If SpecularMapTexture is not set, we look into the opaque data of the model, 
                    //and search for a texture with the key equal to specularMapKey
                    specularMapPath = mesh.OpaqueData.GetValue<string>(specularMapKey, null);
                }

                if (specularMapPath == null)
                {
                    //we search, in the same directory as the model, for a texture named 
                    //meshname_s.tga
                    specularMapPath = Path.Combine(directory, mesh.Name + "_s.tga");
                    if (!File.Exists(specularMapPath))
                    {
                        //if this fails also (that texture does not exist), 
                        //then we use a default texture, named null_specular.tga
                        specularMapPath = "null_specular.tga";
                    }
                }
                else
                {
                    specularMapPath = Path.Combine(directory, specularMapPath);
                }
                //add the keys to the material, so they can be used by the shader
                foreach (GeometryContent geometry in mesh.Geometry)
                {
                    //in some .fbx files, the key might be found in the textures collection, but not
                    //in the mesh, as we checked above. If this is the case, we need to get it out, and
                    //add it with the "NormalMap" key
                    if (geometry.Material.Textures.ContainsKey(normalMapKey))
                    {
                        ExternalReference<TextureContent> texRef = geometry.Material.Textures[normalMapKey];

                        geometry.Material.Textures.Remove(normalMapKey);
                        geometry.Material.Textures.Add("NormalMap", texRef);
                    }
                    else
                        geometry.Material.Textures.Add("NormalMap",
                                        new ExternalReference<TextureContent>(normalMapPath));

                    if (geometry.Material.Textures.ContainsKey(specularMapKey))
                    {
                        ExternalReference<TextureContent> texRef = geometry.Material.Textures[specularMapKey];
                        geometry.Material.Textures.Remove(specularMapKey);
                        geometry.Material.Textures.Add("SpecularMap", texRef);
                    }
                    else
                        geometry.Material.Textures.Add("SpecularMap",
                                    new ExternalReference<TextureContent>(specularMapPath));
                }
            }

            // go through all children and apply LookUpTextures recursively
            foreach (NodeContent child in node.Children)
            {
                LookUpTextures(child);
            }
        }

        [DisplayName("Specular Map Texture")]
        [Description("If set, this file will be used as the specular map on the model, " +
        "overriding anything found in the opaque data.")]
        [DefaultValue("")]
        public string SpecularMapTexture
        {
            get { return specularMapTexture; }
            set { specularMapTexture = value; }
        }
        private string specularMapTexture;

        [DisplayName("Specular Map Key")]
        [Description("This will be the key that will be used to search the specular map in the opaque data of the model")]
        [DefaultValue("SpecularMap")]
        public string SpecularMapKey
        {
            get { return specularMapKey; }
            set { specularMapKey = value; }
        }
        private string specularMapKey = "SpecularMap";

        private string effectDirectory = "Effects\\";

        protected override MaterialContent ConvertMaterial(
            MaterialContent material,
            ContentProcessorContext context)
        {          
            EffectMaterialContent deferredShadingMaterial = new EffectMaterialContent();
            deferredShadingMaterial.Effect = new ExternalReference<EffectContent>
                (effectDirectory + "RenderGBuffer.fx");

            // copy the textures in the original material to the new normal mapping
            // material, if they are relevant to our renderer. The
            // LookUpTextures function has added the normal map and specular map
            // textures to the Textures collection, so that will be copied as well.
            foreach (KeyValuePair<String, ExternalReference<TextureContent>> texture
            in material.Textures)
            {
                if ((texture.Key == "Texture") ||
                        (texture.Key == "NormalMap") ||
                        (texture.Key == "SpecularMap"))
                    deferredShadingMaterial.Textures.Add(texture.Key, texture.Value);
            }

            return context.Convert<MaterialContent, MaterialContent>(deferredShadingMaterial, typeof(MaterialProcessor).Name);
        }
    }

}