using System;
using System.Collections.Generic;
using System.Linq;
using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using Microsoft.Xna.Framework.Storage;
using Microsoft.Xna.Framework.Content;
using Meteor.Resources;

namespace Meteor.Rendering
{
    public partial class DeferredRenderer : Microsoft.Xna.Framework.DrawableGameComponent
    {
        private Camera camera;
        private QuadRenderComponent quadRenderer;
        Scene scene;

        // Color and specular intensity
        RenderTarget2D colorRT;

        // Normals and specular power
        RenderTarget2D[] normalRT;

        // Scene depth
        RenderTarget2D depthRT;

        // Light pass
        RenderTarget2D lightRT;

        // Final combined pass
        RenderTarget2D[] finalRT;

        // Handles directional lights
        Effect directionalLightEffect;

        // Handles point lights
        Effect pointLightEffect;

        // Combines lights with diffuse color
        Effect finalComboEffect;

        // Sphere used for point lighting
        Model sphereModel;

        /// Vertex buffer to hold the instance data
        DynamicVertexBuffer instanceVertexBuffer;

        // Parameters to set render options
        int rtIndex = 0;
        int blur = 0;

        enum RtView
        {
            final,
            diffuse,
            normal,
            lights
        };

        RtView rtView;

        // Pixel offset value
        Vector2 halfPixel;

        // Useful for all DrawableComponents
        SpriteBatch spriteBatch;

        BlendState alphaBlendState = new BlendState()
        {
            AlphaBlendFunction = BlendFunction.Add,
            AlphaSourceBlend = Blend.One,
            AlphaDestinationBlend = Blend.One,

            ColorBlendFunction = BlendFunction.Add,
            ColorSourceBlend = Blend.One,
            ColorDestinationBlend = Blend.One
        };

        /// To store instance transform matrices in a vertex buffer, we use this custom
        /// vertex type which encodes 4x4 matrices as a set of four Vector4 values.
        static VertexDeclaration instanceVertexDeclaration = new VertexDeclaration
        (
            new VertexElement(0, VertexElementFormat.Vector4, VertexElementUsage.TextureCoordinate, 1),
            new VertexElement(16, VertexElementFormat.Vector4, VertexElementUsage.TextureCoordinate, 2),
            new VertexElement(32, VertexElementFormat.Vector4, VertexElementUsage.TextureCoordinate, 3),
            new VertexElement(48, VertexElementFormat.Vector4, VertexElementUsage.TextureCoordinate, 4),
            new VertexElement(64, VertexElementFormat.Color, VertexElementUsage.Color, 1)
        );

        public DeferredRenderer(Game game, Scene scene)
            : base(game)
        {
            this.scene = scene;
        }

        /// <summary>
        /// Set common parameters to reduce state changes
        /// </summary> 

        private void SetCommonParameters(Effect effect)
        {
            // Set Matrix parameters
            effect.Parameters["World"].SetValue(Matrix.Identity);
            effect.Parameters["View"].SetValue(camera.View);
            effect.Parameters["Projection"].SetValue(camera.Projection);

            // Set the G-Buffer parameters
            effect.Parameters["colorMap"].SetValue(colorRT);
            effect.Parameters["normalMap"].SetValue(normalRT[rtIndex]);
            effect.Parameters["depthMap"].SetValue(depthRT);

            effect.Parameters["camPosition"].SetValue(camera.Position);
            effect.Parameters["invertViewProj"].SetValue(
                Matrix.Invert(camera.View * camera.Projection));
            effect.Parameters["halfPixel"].SetValue(halfPixel);
        }

        private void DrawDirectionalLight(Vector3 lightDir, Color lightColor)
        {
            SetCommonParameters(directionalLightEffect);

            directionalLightEffect.Parameters["lightDirection"].SetValue(lightDir);
            directionalLightEffect.Parameters["lightColor"].SetValue(lightColor.ToVector3());

            foreach (EffectPass pass in directionalLightEffect.CurrentTechnique.Passes)
            {
                pass.Apply();
                quadRenderer.Render(Vector2.One * -1, Vector2.One);
            }
        }

        private void DrawPointLights(Scene scene, Camera camera)
        {
            SetCommonParameters(pointLightEffect);

            foreach (PointLight light in scene.pointLights)
            {
                pointLightEffect.Parameters["lightIntensity"].SetValue(light.intensity);
                float camToCenter = Vector3.Distance(camera.Position, light.position);

                // Set the culling mode based on the camera's position relative to the light
                GraphicsDevice.RasterizerState = (camToCenter < light.radius) ?
                      RasterizerState.CullClockwise : RasterizerState.CullCounterClockwise;

                // If we have more instances than room in our vertex buffer, grow it to the neccessary size.
                if ((instanceVertexBuffer == null) ||
                    (1 > instanceVertexBuffer.VertexCount))
                {
                    if (instanceVertexBuffer != null)
                        instanceVertexBuffer.Dispose();

                    instanceVertexBuffer = new DynamicVertexBuffer(
                        GraphicsDevice, instanceVertexDeclaration, 1, BufferUsage.WriteOnly);
                }

                // Transfer the latest instance transform matrices into the instanceVertexBuffer
                // Optionally, use the instance color as well
                instanceVertexBuffer.SetData(light.Instances, 0, 1, SetDataOptions.Discard);

                // Draw the point light

                foreach (ModelMesh mesh in sphereModel.Meshes)
                {
                    foreach (ModelMeshPart meshPart in mesh.MeshParts)
                    {
                        // Tell the GPU to read from both the model vertex buffer plus our instanceVertexBuffer
                        GraphicsDevice.SetVertexBuffers(
                            new VertexBufferBinding(meshPart.VertexBuffer, meshPart.VertexOffset, 0),
                            new VertexBufferBinding(instanceVertexBuffer, 0, 1)
                        );

                        GraphicsDevice.Indices = meshPart.IndexBuffer;

                        foreach (EffectPass pass in pointLightEffect.CurrentTechnique.Passes)
                        {
                            pass.Apply();
                            GraphicsDevice.DrawInstancedPrimitives(
                                PrimitiveType.TriangleList, 0, 0,
                                meshPart.NumVertices, meshPart.StartIndex,
                                meshPart.PrimitiveCount, light.Instances.Length);

                            break;
                        }
                    }
                }
            }

            // Reset the culling mode
            GraphicsDevice.RasterizerState = RasterizerState.CullCounterClockwise;
        }

        /// <summary>
        /// Update and draw all directional and point lights
        /// </summary>

        public void DrawLights(GameTime gameTime)
        {
            float angle = (float)gameTime.TotalGameTime.TotalSeconds;

            GraphicsDevice.SetRenderTarget(lightRT);
            GraphicsDevice.Clear(Color.Black);

            GraphicsDevice.BlendState = alphaBlendState;

            // Make some lights
            DrawDirectionalLight(new Vector3(0, 1f, -1f), Color.DarkGray);

            DrawDirectionalLight(new Vector3(
               -(float)Math.Sin(angle), 0.1f,
                (float)Math.Cos(angle)), Color.Cornsilk);

            DrawPointLights(scene, camera);
        }

        private void DrawCombined()
        {
            if (rtView == 0)
            {
                GraphicsDevice.SetRenderTarget(finalRT[0]);
                GraphicsDevice.Clear(Color.Black);
                GraphicsDevice.BlendState = BlendState.Opaque;

                // Combine lighting effects with diffuse color
                finalComboEffect.Parameters["diffuseMap"].SetValue(colorRT);
                finalComboEffect.Parameters["depthMap"].SetValue(depthRT);
                finalComboEffect.Parameters["lightMap"].SetValue(lightRT);
                finalComboEffect.Parameters["halfPixel"].SetValue(halfPixel);

                finalComboEffect.CurrentTechnique = finalComboEffect.Techniques["Technique1"];
                finalComboEffect.CurrentTechnique.Passes[0].Apply();
                quadRenderer.Render(Vector2.One * -1, Vector2.One);

                if (blur == 1)
                {
                    finalComboEffect.CurrentTechnique = finalComboEffect.Techniques["DepthOfField"];
                    int totalPasses = finalComboEffect.CurrentTechnique.Passes.Count;

                    for (int i = 0; i < totalPasses; i++)
                    {
                        GraphicsDevice.SetRenderTarget(finalRT[1 - i % 2]);
                        GraphicsDevice.Clear(Color.Black);

                        // Depth of field blur effect
                        finalComboEffect.Parameters["diffuseMap"].SetValue(finalRT[i % 2]);
                        finalComboEffect.Parameters["halfPixel"].SetValue(halfPixel);

                        finalComboEffect.CurrentTechnique.Passes[i].Apply();
                        quadRenderer.Render(Vector2.One * -1, Vector2.One);
                    }
                }
            }

            RenderTarget2D[] currentRT = 
            {
                finalRT[0], 
                colorRT, 
                normalRT[rtIndex], 
                lightRT
            };
            
            GraphicsDevice.SetRenderTarget(null);
            spriteBatch.Begin();
            spriteBatch.Draw(currentRT[Convert.ToInt16(rtView)], new Rectangle(0, 0,
                GraphicsDevice.Viewport.Width, GraphicsDevice.Viewport.Height), Color.White);
            spriteBatch.End();
        }
    }
}
