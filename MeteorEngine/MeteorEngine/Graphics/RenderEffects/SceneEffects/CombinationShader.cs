using System;
using System.Collections.Generic;
using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Content;

namespace Meteor.Rendering
{
    class CompositeShader : BaseRenderer
    {
        /// Final combined pass
        RenderTarget2D finalRT;

		/// Selected render pass
		public int passIndex = 0;
		public int includeSSAO = 1;

        /// Combines lights with diffuse color
        Effect finalComboEffect;

		Random randomNumber;

        public CompositeShader(RenderProfile profile, ContentManager content)
            : base(profile, content) 
		{
            // Light and combined effect targets
			finalRT = profile.AddRenderTarget(backBufferWidth,
				backBufferHeight, SurfaceFormat.Rgba1010102, DepthFormat.None);

			randomNumber = new Random();

			outputTargets = new RenderTarget2D[]
			{
				finalRT
			};

            // Load the shader effects
            finalComboEffect = content.Load<Effect>("Effects\\finalCombo");
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
			finalComboEffect.Parameters["ssaoMap"].SetValue(inputTargets[2]);
			finalComboEffect.Parameters["includeSSAO"].SetValue(includeSSAO);
			finalComboEffect.Parameters["flicker"].SetValue(1);//(float)randomNumber.NextDouble());

			finalComboEffect.Parameters["ambient"].SetValue(scene.ambientLight);
            finalComboEffect.Parameters["halfPixel"].SetValue(halfPixel);

            finalComboEffect.CurrentTechnique.Passes[0].Apply();
            quadRenderer.Render(Vector2.One * -1, Vector2.One);

			return outputs;
        }
    }
}
