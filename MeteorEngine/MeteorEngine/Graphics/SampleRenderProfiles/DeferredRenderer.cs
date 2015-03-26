using System;
using System.Collections.Generic;
using System.Diagnostics;
using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using Microsoft.Xna.Framework.Content;
using Meteor.Resources;

namespace Meteor.Rendering
{
	class DeferredRenderer : RenderProfile
	{
		/// Used for drawing the GBuffer
		GBufferShader gBuffer;

		/// Used for drawing the light map
		LightShader lights;

		/// Forward render with color map
		ForwardShader diffuse;

		/// Comination render for final image
		CompositeShader composite;

		/// Render post process blur
		BlurShader blur;

		/// The bloom shader
		BloomShader bloom;

		/// Helper to copy image
		CopyShader copy;

		/// Depth of field effect
		DepthOfFieldShader dof;

		/// DLAA effect	
		DLAAShader dlaa;

		/// SSAO effect
		SSAOShader ssao;

		/// <summary>
		/// Load all the renderers needed for this profile
		/// </summary>

		public DeferredRenderer(IServiceProvider service, ContentManager content)
			: base(service, content) { Initialize(); }

		/// <summary>
		/// Load all the renderers needed for this profile
		/// </summary>

		public override void Initialize()
		{
			base.Initialize();

			gBuffer = new GBufferShader(this, content);
			lights = new LightShader(this, content);
			diffuse = new ForwardShader(this, content);
			composite = new CompositeShader(this, content);
			dof = new DepthOfFieldShader(this, content);
			blur = new BlurShader(this, content);
			copy = new CopyShader(this, content);
			bloom = new BloomShader(this, content);
			dlaa = new DLAAShader(this, content);
			ssao = new SSAOShader(this, content);
		}

		/// <summary>
		/// Map all render target inputs to link the shaders
		/// </summary>

		public void MapInputs(Scene scene, Camera camera)
		{
			debugTargets.Clear();

			// Map the renderer inputs to outputs
			gBuffer.SetInputs(scene, camera, null);
			lights.SetInputs(scene, camera, gBuffer.outputs);
			composite.SetInputs(scene, camera, gBuffer.outputs[2], lights.outputs[0], ssao.outputs[0]);
			dlaa.SetInputs(composite.outputs);
			copy.SetInputs(dlaa.outputs);
			blur.SetInputs(dlaa.outputs);
			ssao.SetInputs(scene, camera, gBuffer.outputs[0], gBuffer.outputs[1],
				lights.outputs[3]);
			bloom.SetInputs(composite.outputs);

			//composite.includeSSAO = 0;

			// Set the debug targets
			debugTargets.Add(gBuffer.outputs[0]);
			debugTargets.Add(gBuffer.outputs[1]);
			debugTargets.Add(gBuffer.outputs[2]);
			debugTargets.Add(lights.outputs[0]);//lights.outputs[0]);
		}

		public override void Draw(GameTime gameTime)
		{
			// Create the lighting map
			gBuffer.Draw();
			lights.Draw();

			// Composite drawing
			composite.Draw();

			// Post effects
			dlaa.Draw();
			//copy.Draw();
			//blur.Draw();

			//(dof as DepthOfFieldShader).Draw(copy.outputs[0], dlaa.outputs[0], gBuffer.outputs[1]);
			output = ssao.Draw()[0];
		}
	}
}
