using System;
using System.Collections.Generic;
using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Content;
using Meteor.Resources;

namespace Meteor.Rendering
{
	/// <summary>
	/// Screen-space antialiasing
	/// A nice post-effect for deferred rendering
	/// </summary>

	class SSAOShader : BaseRenderer
	{
		/// Final combined pass
		RenderTarget2D[] finalRT;

		public override RenderTarget2D[] outputs
		{
            get
            {
                return outputTargets;
            }
        }

		public float radius = 0.5f;
		public float intensity = 0.75f;
		public float scale = 0.2f;
		public float bias = 0.0001f;

		/// Normal map of random values to sample from
		Texture2D randomMap;

		/// Combines lights with diffuse color
		Effect ssaoEffect;

		/// Blur effect for SSAO
		Effect blurEffect;

		/// For mixing up the normal sampling
		Random randomNumber;

		/// Implementation for blur
		GaussianBlur blur;

		public SSAOShader(RenderProfile profile, ContentManager content)
			: base(profile, content) 
		{
			// Light and combined effect targets
			finalRT = new RenderTarget2D[2];

			finalRT[0] = profile.AddRenderTarget(backBufferWidth / 1,
				backBufferHeight / 1, SurfaceFormat.Alpha8, DepthFormat.None);

			finalRT[1] = profile.AddRenderTarget(backBufferWidth / 1,
				backBufferHeight / 1, SurfaceFormat.Alpha8, DepthFormat.None);
			
			outputTargets = new RenderTarget2D[]
			{
				finalRT[0], finalRT[1]
			};

			randomNumber = new Random();
			randomMap = content.Load<Texture2D>("random");

			// Load the shader effects
			ssaoEffect = content.Load<Effect>("Effects\\ssao");
			ssaoEffect.Parameters["halfPixel"].SetValue(halfPixel);

            blurEffect = content.Load<Effect>("Effects\\blur");
			blurEffect.Parameters["halfPixel"].SetValue(halfPixel);

			ssaoEffect.Parameters["g_radius"].SetValue(radius);
			ssaoEffect.Parameters["g_intensity"].SetValue(intensity);
			ssaoEffect.Parameters["g_scale"].SetValue(scale);
			ssaoEffect.Parameters["g_bias"].SetValue(bias);

			ssaoEffect.Parameters["RandomMap"].SetValue(randomMap);

			// Initialize blur
			blur = new GaussianBlur(backBufferWidth, backBufferHeight, 3f, blurEffect);
		}

		/// <summary>
		/// Draw the anti-aliasing effect
		/// </summary>

		public override RenderTarget2D[] Draw()
		{
			renderStopWatch.Reset();
			renderStopWatch.Restart();

			ssaoEffect.CurrentTechnique = ssaoEffect.Techniques[0];

			GraphicsDevice.BlendState = BlendState.Opaque;
			GraphicsDevice.SetRenderTarget(finalRT[0]);
			GraphicsDevice.Clear(Color.White);

			// SSAO effect
			ssaoEffect.Parameters["View"].SetValue(camera.View);
			ssaoEffect.Parameters["Projection"].SetValue(camera.Projection);
			ssaoEffect.Parameters["invertViewProj"].SetValue(Matrix.Invert(camera.View * camera.Projection));
			ssaoEffect.Parameters["invertProjection"].SetValue(Matrix.Invert(camera.Projection));

			ssaoEffect.Parameters["NormalBuffer"].SetValue(inputTargets[0]);
			ssaoEffect.Parameters["DepthBuffer"].SetValue(inputTargets[1]);

			ssaoEffect.CurrentTechnique.Passes[0].Apply();
			quadRenderer.Render(Vector2.One * -1, Vector2.One);
			
			// Blur the SSAO for noise reduction
			blurEffect.CurrentTechnique = blurEffect.Techniques["GaussianBlur"];
			/*
			// blur effect
			for (int i = 0; i < 2; i++)
			{
				GraphicsDevice.SetRenderTarget(finalRT[1 - i % 2]);
				GraphicsDevice.Clear(Color.Transparent);

				blurEffect.Parameters["diffuseMap"].SetValue(finalRT[i % 2]);

				// Use horizontal weights for even pass, vertical for odd pass
				if (i % 2 == 0)
				{
					blurEffect.Parameters["sampleWeights"].SetValue(blur.sampleWeightsH);
					blurEffect.Parameters["sampleOffsets"].SetValue(blur.sampleOffsetsH);
				}
				else
				{
					blurEffect.Parameters["sampleWeights"].SetValue(blur.sampleWeightsV);
					blurEffect.Parameters["sampleOffsets"].SetValue(blur.sampleOffsetsV);
				}

				blurEffect.CurrentTechnique.Passes[i].Apply();
				quadRenderer.Render(Vector2.One * -1, Vector2.One);
			}
			*/
			renderStopWatch.Stop();

			return outputs;
		}
	}
}
