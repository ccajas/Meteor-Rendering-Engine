using System;
using System.Collections.Generic;
using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Content;

namespace Meteor.Rendering
{
    class GBufferShader : SmallGBufferShader
    {
        /// Other GBuffer targets and the clear Effect
		/// are inherited from SmallGBuffer

        /// Color and specular intensity
        RenderTarget2D diffuseRT;

		/// <summary>
		/// Load the GBuffer content
		/// </summary> 

        public GBufferShader(RenderProfile profile, ContentManager content)
			: base(profile, content) 
		{
            // Diffuse/albedo render target

            diffuseRT = profile.AddRenderTarget(backBufferWidth,
				backBufferHeight, SurfaceFormat.Color, DepthFormat.Depth24Stencil8);

			outputTargets = new RenderTarget2D[]
			{
				normalRT, depthRT, diffuseRT
			};

			bindingTargets = new RenderTargetBinding[3] 
			{
				outputTargets[2], outputTargets[0], outputTargets[1]
			};
        }

        /// <summary>
        /// Clear the GBuffer and render scene to it
        /// </summary> 

        public override RenderTarget2D[] Draw()
        {
			renderStopWatch.Reset();
			renderStopWatch.Restart();

            // Set the G-Buffer
            GraphicsDevice.BlendState = BlendState.Opaque;
            GraphicsDevice.SetRenderTargets(bindingTargets);
			GraphicsDevice.DepthStencilState = DepthStencilState.Default;
			GraphicsDevice.Clear(Color.Transparent);
			
			// Reset the sampler states after SpriteBatch
			GraphicsDevice.SamplerStates[0] = SamplerState.LinearWrap;
			GraphicsDevice.SamplerStates[1] = SamplerState.LinearWrap;
			
            // Clear the G-Buffer
            clearBufferEffect.CurrentTechnique = clearBufferEffect.Techniques["Clear"];
            clearBufferEffect.CurrentTechnique.Passes[0].Apply();
            quadRenderer.Render(Vector2.One * -1, Vector2.One);

			sceneRenderer.CullLights(scene, camera);
			sceneRenderer.CullModelMeshes(scene, camera);

            // Render the scene
			sceneRenderer.UseTechnique("GBuffer");
			sceneRenderer.Draw(scene, camera);

			// Render the skybox
			// Update the sampler state
			GraphicsDevice.SamplerStates[0] = SamplerState.LinearClamp;
			sceneRenderer.UseTechnique("Skybox");
			sceneRenderer.DrawSkybox(scene, camera);
			
			renderStopWatch.Stop();

            return outputTargets;
        }
    }

	class SmallGBufferShader : BaseRenderer
	{
		/// Normals and specular power
		protected RenderTarget2D normalRT;

		/// Scene depth
		protected RenderTarget2D depthRT;

		/// Clearing GBuffer
		protected Effect clearBufferEffect;

		protected RenderTargetBinding[] bindingTargets;

		/// <summary>
		/// Load the GBuffer content
		/// </summary> 

		public SmallGBufferShader(RenderProfile profile, ContentManager content)
			: base(profile, content) 
		{
			// Normal render targets
			normalRT = profile.AddRenderTarget(backBufferWidth,
				backBufferHeight, SurfaceFormat.Color, DepthFormat.Depth24Stencil8);
			depthRT = profile.AddRenderTarget(backBufferWidth,
				backBufferHeight, SurfaceFormat.Single, DepthFormat.None);

			bindingTargets = new RenderTargetBinding[2];
			bindingTargets[0] = normalRT;
			bindingTargets[1] = depthRT;

			outputTargets = new RenderTarget2D[]
			{
				normalRT, depthRT
			};

			// Load the shader effects
			clearBufferEffect = content.Load<Effect>("Effects\\clearGBuffer");
		}

		/// <summary>
		/// Clear the small GBuffer and render scene to it
		/// </summary> 

		public override RenderTarget2D[] Draw()
		{
			renderStopWatch.Reset();
			renderStopWatch.Restart();

			// Set the small GBuffer
			GraphicsDevice.BlendState = BlendState.Opaque;
			GraphicsDevice.SetRenderTargets(bindingTargets);
			GraphicsDevice.Clear(Color.Transparent);
			GraphicsDevice.DepthStencilState = DepthStencilState.Default;
			GraphicsDevice.SamplerStates[0] = SamplerState.LinearWrap;
			GraphicsDevice.SamplerStates[1] = SamplerState.LinearWrap;

			// Clear the small GBuffer
			clearBufferEffect.CurrentTechnique = clearBufferEffect.Techniques["ClearSmall"];
			clearBufferEffect.CurrentTechnique.Passes[0].Apply();
			quadRenderer.Render(Vector2.One * -1, Vector2.One);

			sceneRenderer.CullLights(scene, camera);
			sceneRenderer.CullModelMeshes(scene, camera);

			// Render the scene
			sceneRenderer.UseTechnique("SmallGBuffer");
			sceneRenderer.Draw(scene, camera);

			renderStopWatch.Stop();
			return outputTargets;
		}
	}
}
