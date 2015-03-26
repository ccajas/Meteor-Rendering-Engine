using System;
using System.Collections.Generic;
using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Content;
using Meteor.Resources;

namespace Meteor.Rendering
{
    class LightShader : BaseRenderer
    {
        /// Light pass
		RenderTarget2D lightRT;

		/// Shadow pass
		RenderTarget2D depthRT;

		/// Projected shadows
		RenderTarget2D shadowRT;

		/// World space position
		RenderTarget2D positionRT;

		/// Cube map shadows
		RenderTargetCube cubeDepthRT;

        /// Handles directional lights
        Effect directionalLightEffect;

        /// Handles point lights
        Effect pointLightEffect;

		/// Create shadow maps
		Effect depthEffect;

        /// Sphere used for point lighting
        Model sphereModel;
 
 		/// Debug point lights
 		public bool wireframe = false;
 
 		/// Used for shadow mappings
 		Camera lightCamera;
 		const int shadowMapSize = 384;
		const int shadowBatchSize = 12;
 
 		public float shadowBrightness = 0.35f;
 
 		/// View and projection matrices for the lights
 		Matrix[] lightViewProj;
 		Vector2[] mapOffsets;
 
 		BlendState alphaBlendState = new BlendState()
 		{
 			AlphaSourceBlend = Blend.One,
 			AlphaDestinationBlend = Blend.One,
 
 			ColorSourceBlend = Blend.One,
 			ColorDestinationBlend = Blend.One
 		};
 
 		BlendState blend = new BlendState
 		{
 			ColorWriteChannels = ColorWriteChannels.Red,
 			ColorWriteChannels1 = ColorWriteChannels.Green
 		};
 
 		DepthStencilState cwDepthState = new DepthStencilState()
 		{
 			DepthBufferWriteEnable = false,
 			DepthBufferFunction = CompareFunction.LessEqual
 		};
 
 		DepthStencilState ccwDepthState = new DepthStencilState()
 		{
 			DepthBufferWriteEnable = false,
 			DepthBufferFunction = CompareFunction.GreaterEqual
 		};
 
 		// Corners for bounding box to enclose from
 		Vector3[] tempCorners;
 
 		/// Vertex buffer to hold the point light instance data
 		DynamicVertexBuffer instanceVertexBuffer;
 
 		/// Vertex buffer to hold view matrix instance data
 		DynamicVertexBuffer matrixVertexBuffer;
 
         public LightShader(RenderProfile profile, ContentManager content) 
             : base(profile, content) 
 		{
 			lightRT = profile.AddRenderTarget(backBufferWidth, backBufferHeight, 
 				SurfaceFormat.HdrBlendable, DepthFormat.None);
 			shadowRT = profile.AddRenderTarget(backBufferWidth, backBufferHeight,
 				SurfaceFormat.Alpha8, DepthFormat.None);
 			positionRT = profile.AddRenderTarget(backBufferWidth, backBufferHeight,
 				SurfaceFormat.Vector4, DepthFormat.None);
 
 			depthRT = profile.AddRenderTarget(shadowMapSize * 8, shadowMapSize * 8,
				SurfaceFormat.Single, DepthFormat.Depth24);
 
 			cubeDepthRT = new RenderTargetCube(GraphicsDevice, 1024, false,
 				SurfaceFormat.Rg32, DepthFormat.Depth24);
 
 			//GraphicsDevice.SetRenderTarget(cubeDepthRT);
 			tempCorners = new Vector3[8];
 
 			outputTargets = new RenderTarget2D[]
 			{
 				lightRT, depthRT, shadowRT, positionRT
 			};
 
 			lightCamera = new Camera();
 			lightCamera.Initialize(shadowMapSize, shadowMapSize);
 			lightViewProj = new Matrix[shadowBatchSize];
 			mapOffsets = new Vector2[shadowBatchSize];
 
             // Load the shader effects
             directionalLightEffect = content.Load<Effect>("Effects\\directionalLight");
             pointLightEffect = content.Load<Effect>("Effects\\pointLight");
 
 			// Load shadow mapping shader effects
 			depthEffect = content.Load<Effect>("Effects\\depth");
 
 			// Set constant parameters
 			directionalLightEffect.Parameters["halfPixel"].SetValue(halfPixel);
 			pointLightEffect.Parameters["halfPixel"].SetValue(halfPixel);
 
             // Load the point light model
             sphereModel = content.Load<Model>("Models\\ball");
 
 			instanceVertexBuffer = new DynamicVertexBuffer(
 				GraphicsDevice, instanceVertexDeclaration, 1000, BufferUsage.WriteOnly);
 
 			matrixVertexBuffer = new DynamicVertexBuffer(
 				GraphicsDevice, matrixVertexDeclaration, 1000, BufferUsage.WriteOnly);
         }
 
         /// <summary>
         /// Update and draw all directional and point lights
         /// </summary>
 
		public override RenderTarget2D[] Draw()
		{
			renderStopWatch.Reset();
			renderStopWatch.Restart();
 
			if (inputTargets != null)
			{
				// Set rendering priority order
				GraphicsDevice.SetRenderTarget(null);
				sceneRenderer.IgnoreCulling(scene, camera);

				// Set the common parameters for all shadow maps
				SetCommonParameters(directionalLightEffect, camera, inputTargets);

				DrawShadowMaps(scene);
				DrawProjectedShadows(scene, inputTargets);
 
                GraphicsDevice.BlendState = alphaBlendState;
                GraphicsDevice.SetRenderTarget(lightRT);
                GraphicsDevice.Clear(Color.Transparent);
 				GraphicsDevice.DepthStencilState = DepthStencilState.None;
 
 				// Make some lights
				DrawDirectionalLights(scene, inputTargets);
 
 				if (scene.totalLights > 0)
 				{
 					DrawPointLights(scene, camera, inputTargets);
 				}
			}
 
 			renderStopWatch.Stop();
 			return outputs;
		}
 
         /// <summary>
         /// Set common parameters to reduce state changes
         /// </summary> 
 
		private void SetCommonParameters(Effect effect, Camera camera, RenderTarget2D[] targets)
        {
			// Set Matrix parameters
			effect.Parameters["View"].SetValue(camera.View);
            effect.Parameters["Projection"].SetValue(camera.Projection);
 
			// Set the G-Buffer parameters
			effect.Parameters["normalMap"].SetValue(targets[0]);
			effect.Parameters["depthMap"].SetValue(targets[1]);
 
			effect.Parameters["camPosition"].SetValue(camera.Position);
			effect.Parameters["invertViewProj"].SetValue(Matrix.Invert(camera.View * camera.Projection));
			effect.Parameters["inverseView"].SetValue(Matrix.Invert(camera.View));
        }
 
         /// <summary>
         /// Draw directional lights to the map
         /// </summary>
 
        private void DrawDirectionalLights(Scene scene, RenderTarget2D[] targets)
        {
 			SetCommonParameters(directionalLightEffect, camera, targets);
 			directionalLightEffect.Parameters["ambient"].SetValue(scene.ambientLight);
			directionalLightEffect.Parameters["shadowViewMap"].SetValue(shadowRT);
 			directionalLightEffect.Parameters["shadowBrightness"].SetValue(shadowBrightness);
 
 			sceneRenderer.CullModelMeshes(scene, camera);
 
			foreach (DirectionLight light in scene.directionalLights)
			{
				directionalLightEffect.Parameters["lightDirection"].SetValue(light.direction);
				directionalLightEffect.Parameters["lightColor"].SetValue(light.color.ToVector3());
				directionalLightEffect.Parameters["lightIntensity"].SetValue(light.intensity);
 
 				directionalLightEffect.CurrentTechnique = directionalLightEffect.Techniques["DrawFinal"];
 
 				EffectPass pass = directionalLightEffect.CurrentTechnique.Passes[0];
 
 				pass.Apply();
 				quadRenderer.Render(Vector2.One * -1, Vector2.One);
             }
         }
 
 		/// To store instance transform matrices in a vertex buffer, we use this custom
 		/// vertex type which encodes 4x4 matrices as a set of four Vector4 values.
 		static VertexDeclaration matrixVertexDeclaration = new VertexDeclaration
 		(
 			new VertexElement(0, VertexElementFormat.Vector4, VertexElementUsage.TextureCoordinate, 1),
 			new VertexElement(16, VertexElementFormat.Vector4, VertexElementUsage.TextureCoordinate, 2),
 			new VertexElement(32, VertexElementFormat.Vector4, VertexElementUsage.TextureCoordinate, 3),
 			new VertexElement(48, VertexElementFormat.Vector4, VertexElementUsage.TextureCoordinate, 4)
 		);
 
 		/// <summary>
 		/// Accumulate the projected shadows
 		/// </summary>
 
		private void DrawProjectedShadows(Scene scene, RenderTarget2D[] targets)
 		{ 			
 			// Set shadow projection render target
 			GraphicsDevice.BlendState = BlendState.AlphaBlend;
 			GraphicsDevice.SetRenderTarget(shadowRT);
 			GraphicsDevice.Clear(Color.Transparent);
 
 			Vector2 shadowMapPixelSize = new Vector2(
 				1f / ((float)shadowMapSize * 8f), 1f / ((float)shadowMapSize * 8f));
 
 			directionalLightEffect.Parameters["shadowMapPixelSize"].SetValue(shadowMapPixelSize);
 			directionalLightEffect.Parameters["shadowMapSize"].SetValue(shadowMapSize * 8f);
 			directionalLightEffect.Parameters["shadowMap"].SetValue(depthRT);
 			
 			foreach (DirectionLight light in scene.directionalLights)
 			{
 				if (light.castsShadows)
 				{
 					directionalLightEffect.CurrentTechnique = directionalLightEffect.Techniques["Shadowed"];
					EffectPass pass = directionalLightEffect.CurrentTechnique.Passes[0];

 					int batch = 0;
 					int j = 0;
 
					foreach (Scene.OrderedMeshData orderedMesh in scene.orderedMeshes)
 					{
						if (j >= 64) break;
 
						// Calculate view projection matrices for shadow map views
 
						InstancedModel model = scene.Model(orderedMesh.modelName);
						model.tempBoxes[orderedMesh.meshID].GetCorners(tempCorners);

						CreateLightViewProjMatrix(light.direction, lightCamera, tempCorners);
						lightViewProj[batch] = lightCamera.View * lightCamera.Projection;

						mapOffsets[batch] = Vector2.Zero;
						mapOffsets[batch].X = (float)(j % 8) / 8f;
						mapOffsets[batch].Y = (float)(j / 8) / 8f;
 
						batch++;
						j++;
 
						if (batch == shadowBatchSize)
						{
							directionalLightEffect.Parameters["mapOffset"].SetValue(mapOffsets);
							directionalLightEffect.Parameters["lightViewProj"].SetValue(lightViewProj);
							directionalLightEffect.Parameters["shadowLoops"].SetValue(shadowBatchSize);

							pass.Apply();
							// Render the quads
							quadRenderer.Render(Vector2.One * -1f, Vector2.One, j / 100f);

							batch = 0;
 						}
 					}
					
 					if (batch > 0)
 					{
 						directionalLightEffect.Parameters["mapOffset"].SetValue(mapOffsets);
 						directionalLightEffect.Parameters["lightViewProj"].SetValue(lightViewProj);
 						directionalLightEffect.Parameters["shadowLoops"].SetValue(batch);
 
 						// Render the quads
 						pass.Apply();
						quadRenderer.Render(Vector2.One * -1f, Vector2.One, j / 100f);
 						batch = 0;
 					}
				
 					// Finish drawing shadows for this light
 				}
 			}
 		}
 
 		/// <summary>
 		/// Draw the shadow maps for directional lights
 		/// </summary>
 
		private void DrawShadowMaps(Scene scene)
 		{
 			foreach (DirectionLight light in scene.directionalLights)
			{
 				if (light.castsShadows)
 				{
 					float yaw = (float)Math.Atan2(light.direction.X, light.direction.Y);
 					float pitch = (float)Math.Atan2(light.direction.Z,
 						Math.Sqrt((light.direction.X * light.direction.X) +
 								  (light.direction.Y * light.direction.Y)));
 
 					lightCamera.SetOrientation(new Vector2(yaw, pitch));
 					lightCamera.Update();

 					GraphicsDevice.SetRenderTarget(depthRT);
 					GraphicsDevice.Clear(Color.White);					
					GraphicsDevice.DepthStencilState = DepthStencilState.Default;

 					int j = 0;

					foreach (Scene.OrderedMeshData orderedMesh in scene.orderedMeshes)
 					{
						if (j >= 64) break;
 
						// Adjust viewport settings to draw to the correct portion
						// of the render target
						Viewport defaultView = GraphicsDevice.Viewport;

						defaultView.Width = shadowMapSize;
						defaultView.Height = shadowMapSize;
						defaultView.X = shadowMapSize * (j % 8);
						defaultView.Y = shadowMapSize * (j / 8);
						GraphicsDevice.Viewport = defaultView;
 
						// Update view matrices
						InstancedModel model = scene.Model(orderedMesh.modelName);
						model.tempBoxes[orderedMesh.meshID].GetCorners(tempCorners);
						CreateLightViewProjMatrix(light.direction, lightCamera, tempCorners);

						depthEffect.Parameters["LightViewProj"].SetValue(lightCamera.View * lightCamera.Projection);
						depthEffect.Parameters["farClip"].SetValue(lightCamera.farSplitPlaneDistance);
 
						// Cull models from this point of view
						sceneRenderer.DrawModelMesh(scene.staticModels[orderedMesh.modelName],
							orderedMesh.meshID, depthEffect, "Default");
 
						j++;
 					}
 					// End drawing mesh shadow maps for this light
 				} 
 				// End light list
 			}
 		}
 
 		/// <summary>
 		/// Creates the WorldViewProjection matrix from the perspective of the 
 		/// light using the cameras bounding frustum to determine what is visible 
 		/// in the scene.
 		/// </summary>
 		/// <returns>The WorldViewProjection for the light</returns>
 		void CreateLightViewProjMatrix(Vector3 lightDirection, Camera lightCamera, Vector3[] boxCorners,
 			float projectionScale = 25f)
 		{
 			// Matrix with that will rotate in points the direction of the light
 			Matrix lightRotation = Matrix.CreateLookAt(Vector3.Zero, -lightDirection, Vector3.Up);
 
 			// Transform the positions of the corners into the direction of the light
 			for (int i = 0; i < boxCorners.Length; i++)
 			{
 				Vector3.Transform(ref boxCorners[i], ref lightRotation, out boxCorners[i]);
 			}
 
 			// Find the smallest box around the points
 			// Create initial variables to hold min and max xyz values for the boundingBox
 			Vector3 cornerMax = new Vector3(float.MinValue);
 			Vector3 cornerMin = new Vector3(float.MaxValue);
 
 			for (int i = 0; i < boxCorners.Length; i++)
 			{
 				// update our values from this vertex
 				cornerMin = Vector3.Min(cornerMin, boxCorners[i]);
 				cornerMax = Vector3.Max(cornerMax, boxCorners[i]);
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
 			lightCamera.Projection = Matrix.CreateOrthographic(boxSize.X, boxSize.Y, -boxSize.Z, 
 				boxSize.Z * projectionScale);
 		}

        /// To store instance transform matrices in a vertex buffer, we use this custom
        /// vertex type which encodes 4x4 matrices as a set of four Vector4 values.
        static VertexDeclaration instanceVertexDeclaration = new VertexDeclaration
        (
            new VertexElement(0, VertexElementFormat.Vector4, VertexElementUsage.TextureCoordinate, 1),
            new VertexElement(16, VertexElementFormat.Vector4, VertexElementUsage.TextureCoordinate, 2),
            new VertexElement(32, VertexElementFormat.Vector4, VertexElementUsage.TextureCoordinate, 3),
            new VertexElement(48, VertexElementFormat.Vector4, VertexElementUsage.TextureCoordinate, 4),
            new VertexElement(64, VertexElementFormat.Color, VertexElementUsage.Color, 1)
        );

		PointLight.InstanceData[] innerLights = new PointLight.InstanceData[1000];
		PointLight.InstanceData[] outerLights = new PointLight.InstanceData[1000];

        /// <summary>
        /// Draw all visible point light spheres.
        /// </summary>

        private void DrawPointLights(Scene scene, Camera camera, RenderTarget2D[] targets)
        {
			SetCommonParameters(pointLightEffect, camera, targets);
			pointLightEffect.Parameters["lightIntensity"].SetValue(scene.pointLights[0].intensity);

			// Create the list of lights for this update

			Vector3 lightPosition = Vector3.Zero;
			Vector3 radiusVector = Vector3.Zero;
			float radius = 1;

			int totalLights = 0;
			int innerTotal = 0;
			int outerTotal = 0;

			/// Separate the lights into two groups, depending on where the
			/// attenuation distance is relative to the camera's position.
			/// "Inner" lights have the camera inside its lit area, while
			/// "outer" lights don't contain the camera at all.
			/// </summary>

			DepthStencilState _preSparkStencil = new DepthStencilState();
			_preSparkStencil.StencilEnable = true;
			_preSparkStencil.StencilFunction = CompareFunction.Always;
			_preSparkStencil.StencilPass = StencilOperation.Replace;  
			_preSparkStencil.ReferenceStencil = 1;
			_preSparkStencil.DepthBufferEnable = true;

			DepthStencilState _sparkStencil = new DepthStencilState();
			_sparkStencil.StencilEnable = true;
			_sparkStencil.StencilFunction = CompareFunction.NotEqual;
			_sparkStencil.StencilPass = StencilOperation.Keep;  
			_sparkStencil.ReferenceStencil = 1;
			_sparkStencil.DepthBufferEnable = true;

			GraphicsDevice.DepthStencilState = _preSparkStencil;

			foreach (PointLight light in scene.VisiblePointLights) 
			{
				lightPosition.X = light.instance.transform.M41;
				lightPosition.Y = light.instance.transform.M42;
				lightPosition.Z = light.instance.transform.M43;

				radiusVector.X = light.instance.transform.M11;
				radiusVector.Y = light.instance.transform.M12;
				radiusVector.Z = light.instance.transform.M13;

				float camToCenter = Vector3.Distance(camera.Position, lightPosition);
				radius = radiusVector.Length();

				BoundingSphere bSphere = new BoundingSphere(lightPosition, radius * 1.25f);
				PlaneIntersectionType planeIntersectionType;
				camera.Frustum.Near.Intersects(ref bSphere, out planeIntersectionType);

				if (planeIntersectionType != PlaneIntersectionType.Front) 
				{
					innerLights[totalLights]	= light.instance;
					innerTotal++;
				}
				else
				{
					outerLights[totalLights] = light.instance;
					outerTotal++;
				}
				totalLights++;
			}

            // Set the culling mode based on the camera's position relative to the light

			// Draw the inner lights culling clockwise triangles
			GraphicsDevice.RasterizerState = RasterizerState.CullClockwise;
			GraphicsDevice.DepthStencilState = cwDepthState;
			DrawLightGroup(innerLights, innerTotal);

            // Flip the culling mode for the outer lights, also resetting it to default
            GraphicsDevice.RasterizerState = RasterizerState.CullCounterClockwise;
			GraphicsDevice.DepthStencilState = ccwDepthState;
			DrawLightGroup(outerLights, outerTotal);
        }

		/// <summary>
		/// Draw each instanced light group
		/// </summary>

		private void DrawLightGroup(PointLight.InstanceData[] lights, int total)
		{
			int totalInstances = total;
			if (totalInstances <= 0) return;

			// Transfer the latest instance transform matrices into the instanceVertexBuffer
			// Optionally, use the instance color as well
			instanceVertexBuffer.SetData(lights, 0, totalInstances, SetDataOptions.Discard);

			// Draw the point light
			
			foreach (ModelMesh mesh in sphereModel.Meshes)
			{
				foreach (ModelMeshPart meshPart in mesh.MeshParts)
				{					
					// Tell the GPU to read from both the model vertex buffer plus our instanceVertexBuffer
					GraphicsDevice.SetVertexBuffers(
						new VertexBufferBinding(meshPart.VertexBuffer, meshPart.VertexOffset, 0),
						new VertexBufferBinding(instanceVertexBuffer, 0, 1)
					);

					GraphicsDevice.Indices = meshPart.IndexBuffer;

					EffectPass pass = pointLightEffect.CurrentTechnique.Passes[0];
					pass.Apply();
						
					GraphicsDevice.DrawInstancedPrimitives(
						PrimitiveType.TriangleList, 0, 0,
						meshPart.NumVertices, meshPart.StartIndex,
						meshPart.PrimitiveCount, totalInstances);				
				}
			}
			
			// Finish rendering spheres
		}

		/// <summary>
		/// Remove the vertex buffer and sphere model.
		/// </summary> 

		protected new void DisposeResources()
		{
			base.DisposeResources();
		}
    }
}
