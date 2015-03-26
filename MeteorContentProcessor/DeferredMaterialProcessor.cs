
using System;
using System.Collections.Generic;
using System.Text;
using Microsoft.Xna.Framework.Content.Pipeline;
using Microsoft.Xna.Framework.Content.Pipeline.Graphics;
using Microsoft.Xna.Framework.Content.Pipeline.Processors;
using System.ComponentModel;

namespace DeferredRenderingPipeline
{
    /// <summary>
    /// The NormalMappingMaterialProcessor is very simple.  It extends the regular
    /// MaterialProcessor, overriding BuildTexture so that normal maps can go through
    /// the NormalMapTextureProcessor and be converted to a signed normalmap format.
    /// </summary>
    [ContentProcessor]
    [DesignTimeVisible(false)]
    public class DeferredMaterialProcessor : MaterialProcessor
    {
        protected override ExternalReference<TextureContent> BuildTexture
            (string textureName, ExternalReference<TextureContent> texture,
            ContentProcessorContext context)
        {
            if (textureName == MeteorModelProcessor.NormalMapKey)
            {
                // put the normal map through the special NormalMapTextureProcessor,
                // which will convert it to a signed format.
                return context.BuildAsset<TextureContent, TextureContent>(texture,
                    typeof(DeferredTextureProcessor).Name);
            }

            // Apply default processing to all other textures.
            return base.BuildTexture(textureName, texture, context);
        }
    }
}