
using System;
using System.Collections.Generic;
using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Content;
using Meteor.Resources;

namespace Meteor.Rendering
{
	class BloomShader : BaseRenderer
	{
		/// Configurable parameters
		public float threshold;
		public float bloomIntensity;
		public float blurStep;
		public float saturation;
		public float contrast;

        /// Final combined pass
        RenderTarget2D[] finalRT;

        public override RenderTarget2D[] outputs
        {
            get
            {
                return finalRT;
            }
        }

        /// Effect for blurring and blooming
        Effect blurEffect;
		GaussianBlur blur;

        public BloomShader(RenderProfile profile, ContentManager content)
            : base(profile, content)
        {
			threshold = 0.4f;
			bloomIntensity = 1.1f;
			blurStep = 1.0f;

			saturation = 1.0f;
			contrast = 1.0f;

			finalRT = new RenderTarget2D[3];

            // Light and combined effect targets
			finalRT[0] = profile.AddRenderTarget(backBufferWidth,
				backBufferHeight, SurfaceFormat.Rgba1010102, DepthFormat.None);

			finalRT[1] = profile.AddRenderTarget(backBufferWidth,
				backBufferHeight / 2, SurfaceFormat.Rgba1010102, DepthFormat.None);
			finalRT[2] = profile.AddRenderTarget(backBufferWidth,
				backBufferHeight / 2, SurfaceFormat.Rgba1010102, DepthFormat.None);

            // Load the shader effects
            blurEffect = content.Load<Effect>("Effects\\blur");
			blur = new GaussianBlur(backBufferWidth, backBufferHeight, blurStep, blurEffect);
        }

        /// <summary>
        /// Draw the blur effect
        /// </summary>

        public override RenderTarget2D[] Draw()
        {	
            //finalRT[0] = target; // This is the composite render target
            int totalPasses;

			renderStopWatch.Reset();
			renderStopWatch.Restart();

            blurEffect.CurrentTechnique = blurEffect.Techniques["SimpleBloom"];
			blurEffect.Parameters["threshold"].SetValue(threshold);
			blurEffect.Parameters["bloomFactor"].SetValue(bloomIntensity);

            totalPasses = blurEffect.CurrentTechnique.Passes.Count;

			GraphicsDevice.SetRenderTarget(finalRT[2]);
			GraphicsDevice.Clear(Color.Transparent);

			blurEffect.Parameters["diffuseMap"].SetValue(finalRT[1]);
			blurEffect.Parameters["blurMap"].SetValue(inputTargets[0]);

			blurEffect.CurrentTechnique.Passes[0].Apply();
			quadRenderer.Render(Vector2.One * -1, Vector2.One);

			GraphicsDevice.SetRenderTarget(finalRT[1]);
			GraphicsDevice.Clear(Color.Transparent);

			blurEffect.Parameters["diffuseMap"].SetValue(finalRT[2]);
			blurEffect.Parameters["sampleWeights"].SetValue(blur.sampleWeightsH);
			blurEffect.Parameters["sampleOffsets"].SetValue(blur.sampleOffsetsH);

			blurEffect.CurrentTechnique.Passes[1].Apply();
			quadRenderer.Render(Vector2.One * -1, Vector2.One);

			GraphicsDevice.SetRenderTarget(finalRT[2]);
			GraphicsDevice.Clear(Color.Transparent);

			blurEffect.Parameters["diffuseMap"].SetValue(finalRT[1]);
			blurEffect.Parameters["sampleWeights"].SetValue(blur.sampleWeightsV);
			blurEffect.Parameters["sampleOffsets"].SetValue(blur.sampleOffsetsV);

			blurEffect.CurrentTechnique.Passes[2].Apply();
			quadRenderer.Render(Vector2.One * -1, Vector2.One);
			
			GraphicsDevice.SetRenderTarget(finalRT[0]);
			GraphicsDevice.Clear(Color.Transparent);

			blurEffect.Parameters["blurMap"].SetValue(finalRT[2]);
			blurEffect.Parameters["diffuseMap"].SetValue(inputTargets[0]);
			blurEffect.Parameters["saturation"].SetValue(saturation);
			blurEffect.Parameters["contrast"].SetValue(contrast);

			blurEffect.CurrentTechnique.Passes[3].Apply();
			quadRenderer.Render(Vector2.One * -1, Vector2.One);
			/*
            for (int i = 0; i < 3; i++)
            {
                GraphicsDevice.SetRenderTarget(finalRT[1 - i % 2]);
                GraphicsDevice.Clear(Color.Transparent);

				// Use horizontal weights for even pass, vertical for odd pass
				if (i % 2 == 1)
				{
					blurEffect.Parameters["sampleWeights"].SetValue(blur.sampleWeightsH);
					blurEffect.Parameters["sampleOffsets"].SetValue(blur.sampleOffsetsH);
				}
				else
				{
					blurEffect.Parameters["sampleWeights"].SetValue(blur.sampleWeightsV);
					blurEffect.Parameters["sampleOffsets"].SetValue(blur.sampleOffsetsV);
				}

                // Apply bloom effect
				blurEffect.Parameters["diffuseMap"].SetValue(finalRT[i % 2]);
                blurEffect.Parameters["blurMap"].SetValue(target);
                blurEffect.CurrentTechnique.Passes[i].Apply();
                quadRenderer.Render(Vector2.One * -1, Vector2.One);
            }
			*/
			renderStopWatch.Stop();

			return outputs;
        }
	}
}
