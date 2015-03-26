using System;
using System.Collections.Generic;
using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Content;
using Meteor.Resources;

namespace Meteor.Rendering
{
	class PSShadowMapper : ShadowMapper
	{
		public PSShadowMapper(RenderProfile profile, ContentManager content)
			: base(profile, content)
		{
			hasSceneInput = true;
			textureSize = 1024;

			lightCamera = new Camera(new Vector3(-100f, 400f, -250f), new Vector2(40, 40));
			lightCamera.Initialize(textureSize, textureSize);

			// Diffuse render target
			shadowRT = profile.AddRenderTarget(backBufferWidth, backBufferHeight,
				SurfaceFormat.Color, DepthFormat.Depth24);

			// Light and combined effect targets
			depthRT = new RenderTarget2D[4];
			for (int i = 0; i < depthRT.Length; i++)
			{
				depthRT[i] = profile.AddRenderTarget(textureSize, textureSize,
					SurfaceFormat.Single, DepthFormat.Depth24);
			}

			// Load the shader effects
			depth = content.Load<Effect>("Effects/depth");
			shadow = content.Load<Effect>("Effects/shadow_pssm");
			blurEffect = content.Load<Effect>("Effects/blur");
		}

		/// <summary>
		/// Simply draw the scene to the render target
		/// </summary> 

		public override RenderTarget2D[] Draw()
		{
			renderStopWatch.Reset();
			renderStopWatch.Restart();

			GraphicsDevice.BlendState = BlendState.Opaque;
			int i = 0;
			
			foreach (DirectionLight light in scene.directionalLights)
			{
				if (light.castsShadows)
				{
					GraphicsDevice.SetRenderTarget(depthRT[i++]);
					GraphicsDevice.Clear(Color.White);

					float yaw = (float)Math.Atan2(light.direction.X, light.direction.Y);
					float pitch = (float)Math.Atan2(light.direction.Z,
						Math.Sqrt((light.direction.X * light.direction.X) + 
								  (light.direction.Y * light.direction.Y)));

					// Update view matrices
					lightCamera.SetOrientation(new Vector2(yaw, pitch));
					lightCamera.Update();

					Matrix lightView = light.LightView(lightCamera.Position);
					Matrix lightProjection = Matrix.CreateOrthographic(1250, 1250, lightCamera.nearPlaneDistance,
						lightCamera.farPlaneDistance);

					depth.Parameters["LightViewProj"].SetValue(lightView * lightProjection);
					depth.Parameters["farClip"].SetValue(lightCamera.farPlaneDistance);

					// Cull models from this point of view
					sceneRenderer.CullModelMeshes(scene, lightCamera);
					sceneRenderer.Draw(scene, depth);
				}
			}
			DrawShadowOverlay();

			renderStopWatch.Stop();
			return outputs;
		}

		private void DrawShadowOverlay()
		{
			// Next draw with the shadow renderer
			//GraphicsDevice.BlendState = BlendState.Additive;
			GraphicsDevice.SetRenderTarget(shadowRT);
			GraphicsDevice.Clear(Color.White);
		
			shadow.Parameters["View"].SetValue(camera.View);
			shadow.Parameters["Projection"].SetValue(camera.Projection);
			shadow.Parameters["farClip"].SetValue(camera.farPlaneDistance);

			sceneRenderer.CullModelMeshes(scene, camera);
			int i = 0;

			foreach (DirectionLight light in scene.directionalLights)
			{
				if (light.castsShadows)
				{
					Matrix lightView = light.LightView(lightCamera.Position);
					Matrix lightProjection = Matrix.CreateOrthographic(1250, 1250, lightCamera.nearPlaneDistance,
						lightCamera.farPlaneDistance);
					Vector2 shadowMapPixelSize = new Vector2(0.5f / textureSize, 0.5f / textureSize);

					shadow.Parameters["ShadowMapSize"].SetValue(textureSize);
					shadow.Parameters["ShadowMapPixelSize"].SetValue(shadowMapPixelSize);
					shadow.Parameters["LightViewProj"].SetValue(Matrix.Multiply(lightView, lightProjection));
					shadow.Parameters["ShadowMap"].SetValue(depthRT[i++]);

					sceneRenderer.Draw(scene, shadow, GraphicsDevice.BlendState);
				}
			}

			// Finished rendering lights
		}
	}
}
