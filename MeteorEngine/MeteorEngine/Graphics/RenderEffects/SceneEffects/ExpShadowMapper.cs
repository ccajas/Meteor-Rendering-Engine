using System;
using System.Collections.Generic;
using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Content;
using Meteor.Resources;

namespace Meteor.Rendering
{
	class ExpShadowMapper : ShadowMapper
	{
		public ExpShadowMapper(RenderProfile profile, ContentManager content)
            : base(profile, content) 
		{
			hasSceneInput = true;
			textureSize = 1024;

            // Diffuse render target
			shadowRT = profile.AddRenderTarget(backBufferWidth, backBufferHeight,
				SurfaceFormat.Color, DepthFormat.Depth24);

			lightCamera = new Camera(new Vector3(-200 * 0.7f, 1400 * 0.7f, 400), new Vector2(40, 40));
			lightCamera.Initialize(textureSize, textureSize);

			depthRT = new RenderTarget2D[2];

			// Light and combined effect targets
			depthRT[0] = profile.AddRenderTarget(textureSize, textureSize,
				SurfaceFormat.Rg32, DepthFormat.Depth24Stencil8);
			depthRT[1] = profile.AddRenderTarget(textureSize, textureSize,
				SurfaceFormat.Color, DepthFormat.Depth24Stencil8);

			outputTargets = new RenderTarget2D[]
			{
				shadowRT, depthRT[0]
			};

			// Load the shader effects
			depth = content.Load<Effect>("Effects/depth_exp");
			shadow = content.Load<Effect>("Effects/shadow_exp");
			blurEffect = content.Load<Effect>("Effects/blur");

			// Setup basic blur parameters
			blur = new GaussianBlur(textureSize, textureSize, 1, blurEffect);
			blurEffect.Parameters["halfPixel"].SetValue(halfPixel);
        }

        /// <summary>
        /// Simply draw the scene to the render target
        /// </summary> 

		public override RenderTarget2D[] Draw()
		{
			renderStopWatch.Reset();
			renderStopWatch.Restart();

			GraphicsDevice.SetRenderTarget(depthRT[0]);
			GraphicsDevice.Clear(Color.White);

			foreach (DirectionLight light in scene.directionalLights)
			{
				if (light.castsShadows)
				{
					Matrix lightView = light.LightView(lightCamera.Position);
					Matrix lightProjection = Matrix.CreatePerspectiveFieldOfView((float)Math.PI / 5f, 
						1f, 1, lightCamera.farPlaneDistance);
					CreateLightViewProjMatrix(light.direction, lightCamera);

					depth.Parameters["LightViewProj"].SetValue(lightCamera.View * lightCamera.Projection);
					depth.Parameters["farClip"].SetValue(lightCamera.farPlaneDistance);

					// Cull models from this point of view
					sceneRenderer.IgnoreCulling(scene, camera);
					sceneRenderer.Draw(scene, depth);
				}
			}

			// Gaussian blur applied
			/*
			blurEffect.CurrentTechnique = blurEffect.Techniques["GaussianBlur"];
			int totalPasses = blurEffect.CurrentTechnique.Passes.Count;
			
			for (int i = 0; i < 2; i++)
			{
				GraphicsDevice.SetRenderTarget(depthRT[1 - i % 2]);
				GraphicsDevice.Clear(new Color(1, 1, 1, 0));

				// Depth of field blur effect
				blurEffect.Parameters["diffuseMap"].SetValue(depthRT[i % 2]);

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
			DrawShadowOverlay();
			renderStopWatch.Stop();

			return outputs;
		}

		/// <summary>
		/// Creates the WorldViewProjection matrix from the perspective of the 
		/// light using the cameras bounding frustum to determine what is visible 
		/// in the scene.
		/// </summary>
		/// <returns>The WorldViewProjection for the light</returns>
		void CreateLightViewProjMatrix(Vector3 lightDirection, Camera lightCamera)
		{
			// Matrix with that will rotate in points the direction of the light
			Matrix lightRotation = Matrix.CreateLookAt(Vector3.Zero, -lightDirection, Vector3.Up);
			camera.Frustum.GetCorners(camera);

			// Transform the positions of the corners into the direction of the light
			for (int i = 0; i < camera.frustumCorners.Length; i++)
			{
				Vector3.Transform(ref camera.frustumCorners[i], ref lightRotation, out camera.frustumCorners[i]);
			}

			// Find the smallest box around the points
			// Create initial variables to hold min and max xyz values for the boundingBox
			Vector3 cornerMax = new Vector3(float.MinValue);
			Vector3 cornerMin = new Vector3(float.MaxValue);

			for (int i = 0; i < camera.frustumCorners.Length; i++)
			{
				// update our values from this vertex
				cornerMin = Vector3.Min(cornerMin, camera.frustumCorners[i]);
				cornerMax = Vector3.Max(cornerMax, camera.frustumCorners[i]);
			}

			BoundingBox lightBox = new BoundingBox(cornerMin, cornerMax);
			Vector3 boxSize = lightBox.Max - lightBox.Min;
			Vector3 halfBoxSize = boxSize * 0.5f;

			// The position of the light should be in the center of the back panel of the box. 
			Vector3 lightPosition = lightBox.Min + halfBoxSize;
			lightPosition.Z = lightBox.Min.Z;

			// We need the position back in world coordinates so we transform 
			// the light position by the inverse of the lights rotation
			lightPosition = Vector3.Transform(lightPosition, Matrix.Invert(lightRotation));

			// Create the view matrix for the light
			lightCamera.View = Matrix.CreateLookAt(lightPosition, lightPosition + lightDirection, Vector3.Up);

			// Create the projection matrix for the light
			// The projection is orthographic since we are using a directional light
			lightCamera.Projection = Matrix.CreateOrthographic(boxSize.X, boxSize.Y,
				-boxSize.Z, boxSize.Z);
		}

		private void DrawShadowOverlay()
		{
			// Next draw with the shadow renderer
			GraphicsDevice.SetRenderTarget(shadowRT);
			GraphicsDevice.Clear(Color.White);

			shadow.Parameters["View"].SetValue(camera.View);
			shadow.Parameters["Projection"].SetValue(camera.Projection);
			shadow.Parameters["farClip"].SetValue(camera.farPlaneDistance);

			sceneRenderer.CullModelMeshes(scene, camera);

			foreach (DirectionLight light in scene.directionalLights)
			{
				if (light.castsShadows)
				{
					Matrix lightView = light.LightView(lightCamera.Position);
					Matrix lightProjection = Matrix.CreatePerspectiveFieldOfView((float)Math.PI / 5f, 
						1f, 1, lightCamera.farPlaneDistance);

					shadow.Parameters["LightViewProj"].SetValue(Matrix.Multiply(lightView, lightProjection));
					shadow.Parameters["ShadowMap"].SetValue(depthRT[0]);

					sceneRenderer.Draw(scene, shadow);
				}
			}
			// Finished rendering lights
		}
	}
}
