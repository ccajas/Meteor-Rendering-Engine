using System;
using System.Collections.Generic;
using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Content;
using Meteor.Resources;

namespace Meteor.Rendering
{
    class ForwardShader : BaseRenderer
    {
        /// Color and specular intensity
        RenderTarget2D diffuseRT;

        Effect gBufferEffect;

        public ForwardShader(RenderProfile profile, ContentManager content)
            : base(profile, content) 
		{
			hasSceneInput = true;

            // Diffuse render target
			diffuseRT = profile.AddRenderTarget(backBufferWidth,
                backBufferHeight, SurfaceFormat.Color, DepthFormat.Depth24);

            //gBufferEffect = content.Load<Effect>("Effects\\renderGBuffer");

			outputTargets = new RenderTarget2D[] 
			{
				diffuseRT
			};
        }

        /// <summary>
        /// Simply draw the scene to the render target
        /// </summary> 

        public override RenderTarget2D[] Draw()
        {
            // Prepare the forward rendering
            GraphicsDevice.SetRenderTarget(diffuseRT);
			GraphicsDevice.Clear(Color.Transparent);
			GraphicsDevice.DepthStencilState = DepthStencilState.Default;
			GraphicsDevice.BlendState = BlendState.Opaque;
			
			// Sampler states for the diffuse map
			GraphicsDevice.SamplerStates[0] = SamplerState.LinearWrap;

			sceneRenderer.CullLights(scene, camera);
			sceneRenderer.CullModelMeshes(scene, camera);
			
            // Forward render the scene
			sceneRenderer.UseTechnique("ForwardRender");
			sceneRenderer.Draw(scene, camera);
			
			// Render the skybox
			// Update sampler state
			GraphicsDevice.SamplerStates[0] = SamplerState.LinearClamp;
			sceneRenderer.UseTechnique("Skybox");
			sceneRenderer.DrawSkybox(scene, camera);
			
			return outputs;
        }
    }
}
