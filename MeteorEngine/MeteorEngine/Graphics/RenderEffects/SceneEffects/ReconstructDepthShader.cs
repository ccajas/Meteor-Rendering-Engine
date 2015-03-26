using System;
using System.Collections.Generic;
using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Content;

namespace Meteor.Rendering
{
	class ReconstructDepthShader : BaseRenderer
	{
		/// Z-Pass target
		RenderTarget2D zPassRT;

		public RenderTarget2D[] target
		{
			get
			{
				RenderTarget2D[] targets = {
					zPassRT
				};

				return targets;
			}
		}

        /// Z-pass effect
        Effect zPassEffect;

        public ReconstructDepthShader(RenderProfile profile, ContentManager content)
            : base(profile, content) 
		{
			hasSceneInput = true;

			// Normal render targets
			zPassRT = profile.AddRenderTarget(backBufferWidth, backBufferHeight, 
				SurfaceFormat.Color, DepthFormat.Depth24);

			// Load the shader effects
			zPassEffect = content.Load<Effect>("Effects\\zPass");
		}

		/// <summary>
		/// Do an early Z-pass render
		/// </summary> 

		public override RenderTarget2D[] Draw()
		{
			renderStopWatch.Reset();
			renderStopWatch.Restart();

			// Set the ZPass target
			GraphicsDevice.SetRenderTarget(zPassRT);
			GraphicsDevice.BlendState = BlendState.Opaque;
			GraphicsDevice.Clear(Color.Black);

			// Render the scene
			sceneRenderer.UseTechnique("ZPass");
			sceneRenderer.Draw(scene, camera);

			GraphicsDevice.SetRenderTarget(null);

			renderStopWatch.Stop();

			return target;
		}
	}
}
