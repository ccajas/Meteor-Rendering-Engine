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
	class LightPrePassRenderer : RenderProfile
	{
		/// Used for drawing the GBuffer
		BaseRenderer smallGBuffer;

		/// Used for drawing the light map
		BaseRenderer lights;

		/// Forward render with color map
		BaseRenderer diffuse;

		/// Helper to copy image
		BaseRenderer copy;

		/// Comination render for final image
		BaseRenderer composite;

		/// Render post process blur
		BaseRenderer blur;

		/// The bloom shader
		BaseRenderer bloom;

		/// Depth of field effect
		BaseRenderer dof;

		/// FXAA effect
		BaseRenderer dlaa;

		/// SSAO effect
		BaseRenderer ssao;

		/// <summary>
		/// Load all the renderers needed for this profile
		/// </summary>

		public LightPrePassRenderer(IServiceProvider service, ContentManager content) 
			: base(service, content) { Initialize(); }

		/// <summary>
		/// Load all the renderers needed for this profile
		/// </summary>

		public override void Initialize()
		{
			base.Initialize();

			smallGBuffer =	rendererFactory.Create("SmallGBufferShader", this, content);
			lights =		rendererFactory.Create("LightShader", this, content);
			diffuse =		rendererFactory.Create("ForwardShader", this, content);
			composite =		rendererFactory.Create("CompositeShader", this, content);
			blur =			rendererFactory.Create("BlurShader", this, content);
			copy =			rendererFactory.Create("CopyShader", this, content);
			ssao =			rendererFactory.Create("SSAOShader", this, content);
			dof =			rendererFactory.Create("DepthOfFieldShader", this, content);
			bloom =			rendererFactory.Create("BloomShader", this, content);
			dlaa =			rendererFactory.Create("DLAAShader", this, content);
		}

		/// <summary>
		/// Map all render target inputs to link the shaders
		/// </summary>

		public void MapInputs(Scene scene, Camera camera)
		{
			debugTargets.Clear();

			// Map the renderer inputs to outputs
			smallGBuffer.SetInputs(scene, camera, null);
			diffuse.SetInputs(scene, camera, null);
			lights.SetInputs(scene, camera, smallGBuffer.outputs);
			composite.SetInputs(scene, camera, diffuse.outputs[0], lights.outputs[0], ssao.outputs[0]);
			dlaa.SetInputs(composite.outputs);
			copy.SetInputs(dlaa.outputs);
			blur.SetInputs(copy.outputs);
			dof.SetInputs(dlaa.outputs[0], copy.outputs[0], smallGBuffer.outputs[1]);
			ssao.SetInputs(scene, camera, smallGBuffer.outputs);
			bloom.SetInputs(dlaa.outputs);

			//(composite as CompositeShader).includeSSAO = 0;

			// Set the debug targets
			debugTargets.Add(diffuse.outputs[0]);
			debugTargets.Add(smallGBuffer.outputs[0]);
			debugTargets.Add(lights.outputs[0]);
			debugTargets.Add(lights.outputs[1]);
		}

		public override void Draw(GameTime gameTime)
		{
			// Forward render the scene with diffuse only 
			diffuse.Draw();

			// Create the lighting map
			smallGBuffer.Draw();
			lights.Draw();
			ssao.Draw();
			//blur.Draw();

			// Combine with lighting
            composite.Draw();
			
			// Post effects
			dlaa.Draw();

			// Copy DLAA render output
			//copy.Draw();
			//blur.Draw();

			//dof.Draw();
			output = bloom.Draw()[0];
		}
	}
}
