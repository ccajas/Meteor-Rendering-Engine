using System;
using System.Collections.Generic;
using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Content;
using Meteor.Resources;

namespace Meteor.Rendering
{
	abstract class ShadowMapper : BaseRenderer
	{
		/// Shadow map
		protected RenderTarget2D shadowRT;

		/// Depth map
		protected RenderTarget2D[] depthRT;

		public RenderTarget2D[] depthMaps
		{
			get
			{
				return depthRT;
			}
		}

		protected Camera lightCamera;

		/// Effects used to create and project the shadow map
		protected Effect depth;
		protected Effect shadow;

		/// Gaussian blur for shadows
		protected Effect blurEffect;
		protected GaussianBlur blur;

		/// Default shadow map dimensions (square)
		protected int textureSize;

		protected ShadowMapper(RenderProfile profile, ContentManager content)
			: base(profile, content)
		{
		}

		public virtual void IncreaseDetail()
		{
			textureSize = (textureSize < 4096) ? textureSize * 2 : textureSize;

			depthRT[0].Dispose();
			depthRT[1].Dispose();

			depthRT[0] = new RenderTarget2D(GraphicsDevice, textureSize, textureSize,
				true, SurfaceFormat.Rg32, DepthFormat.Depth24);
			depthRT[1] = new RenderTarget2D(GraphicsDevice, textureSize, textureSize,
				true, SurfaceFormat.Rg32, DepthFormat.Depth24);

			blur = new GaussianBlur(textureSize, textureSize, 1, blurEffect);
		}

		public virtual void DecreaseDetail()
		{
			textureSize = (textureSize > 128) ? textureSize / 2 : textureSize;

			depthRT[0].Dispose();
			depthRT[1].Dispose();

			depthRT[0] = new RenderTarget2D(GraphicsDevice, textureSize, textureSize,
				true, SurfaceFormat.Rg32, DepthFormat.Depth24);
			depthRT[1] = new RenderTarget2D(GraphicsDevice, textureSize, textureSize,
				true, SurfaceFormat.Rg32, DepthFormat.Depth24);

			blur = new GaussianBlur(textureSize, textureSize, 1, blurEffect);
		}

		/// <summary>
		/// Simply draw the scene to the render target
		/// </summary> 

		//public abstract RenderTarget2D[] Draw();
	}
}
