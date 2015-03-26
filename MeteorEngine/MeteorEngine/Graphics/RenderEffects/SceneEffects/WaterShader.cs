using System;
using System.Collections.Generic;
using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Content;

namespace Meteor.Rendering
{
    class WaterShader : BaseRenderer
    {
        /// Final combined pass
        RenderTarget2D finalRT;

		/// Selected render pass
		public int passIndex = 0;

        /// Combines lights with diffuse color
        Effect finalComboEffect;

		public WaterShader(RenderProfile profile, ContentManager content)
            : base(profile, content) 
		{
            // Light and combined effect targets
			finalRT = profile.AddRenderTarget(backBufferWidth,
				backBufferHeight, SurfaceFormat.Color, DepthFormat.None);

			outputTargets = new RenderTarget2D[]
			{
				finalRT
			};

            // Load the shader effects
            finalComboEffect = content.Load<Effect>("Effects\\depthBlend");
        }

        /// <summary>
        /// Draw the final composite scene with lights
        /// </summary>

        public override RenderTarget2D[] Draw()
        {
			// Setup combination render
            GraphicsDevice.SetRenderTarget(finalRT);
			GraphicsDevice.Clear(Color.Transparent);
            GraphicsDevice.BlendState = BlendState.Opaque;

            // Combine lighting effects with diffuse color
            finalComboEffect.Parameters["diffuseMap"].SetValue(inputTargets[0]);
			finalComboEffect.Parameters["lightMap"].SetValue(inputTargets[1]);

			finalComboEffect.Parameters["ambient"].SetValue(scene.ambientLight);
            finalComboEffect.Parameters["halfPixel"].SetValue(halfPixel);

            finalComboEffect.CurrentTechnique.Passes[0].Apply();
            quadRenderer.Render(Vector2.One * -1, Vector2.One);

			return outputs;
        }
    }
}
