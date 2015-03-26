using System;
using System.Collections.Generic;
using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Content;

namespace Meteor.Rendering
{
	/// <summary>
	/// Screen-space antialiasing
	/// A nice post-effect for deferred rendering
	/// </summary>

	class DLAAShader : BaseRenderer
	{
		/// Final combined pass
		RenderTarget2D finalRT;

		/// Combines lights with diffuse color
		Effect dlaaEffect;

		public DLAAShader(RenderProfile profile, ContentManager content)
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
			dlaaEffect = content.Load<Effect>("Effects\\dlaa");

			dlaaEffect.Parameters["bgl_RenderedTextureWidth"].SetValue(backBufferWidth);
			dlaaEffect.Parameters["bgl_RenderedTextureHeight"].SetValue(backBufferHeight);
		}

		/// <summary>
		/// Draw the anti-aliasing effect
		/// </summary>

		public override RenderTarget2D[] Draw()
		{
			renderStopWatch.Reset();
			renderStopWatch.Restart();

			dlaaEffect.CurrentTechnique = dlaaEffect.Techniques[0];

			GraphicsDevice.BlendState = BlendState.AlphaBlend;
			GraphicsDevice.SetRenderTarget(finalRT);
			GraphicsDevice.Clear(Color.Transparent);

			// FXAA effect
			dlaaEffect.Parameters["halfPixel"].SetValue(halfPixel);
			dlaaEffect.Parameters["Texture"].SetValue(inputTargets[0]);
			dlaaEffect.CurrentTechnique.Passes[0].Apply();
			quadRenderer.Render(Vector2.One * -1, Vector2.One);

			renderStopWatch.Stop();

			return outputs;
		}
	}
}
