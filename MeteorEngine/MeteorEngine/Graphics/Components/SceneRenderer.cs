using System;
using System.Collections.Generic;
using System.Linq;
using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Content;
using Microsoft.Xna.Framework.Graphics;
using Meteor.Rendering;
using Meteor.Resources;
using SkinnedModel;

namespace Meteor.Rendering
{
	class MeshPrioritySort : IComparer<Scene.OrderedMeshData>
	{
		#region IComparer<Student> Members

		public int Compare(Scene.OrderedMeshData rp1,
			Scene.OrderedMeshData rp2)
		{
			int returnValue = 1;
			returnValue = rp2.priority.CompareTo(rp1.priority);

			return returnValue;
		}

		#endregion
	}

	class SceneRenderComponent
	{
		/// Temporary effect borrowed from outside source
		Effect activeEffect;

		/// Basic effect to be used for skinned meshes, for now
		BasicEffect basicEffect;

		/// Effect technique used by the scene
		String shaderTechnique;

		/// Scene stats used in rendering
		public int totalPolys;
		public bool debug = false;

		/// For loading scene content
		ContentManager content;
		GraphicsDevice graphicsDevice;
		Texture2D testTexture, testNormal;
		Texture2D blankTexture, blankSpecular;

		MeshPrioritySort meshPrioritySort;

		Vector3[] boxCorners;

	    public SceneRenderComponent(GraphicsDevice device, ContentManager content)
        {
			this.graphicsDevice = device; 
			this.content = content;

            // Use standard GBuffer as a default
            shaderTechnique = "GBuffer";

			activeEffect = null;

			testTexture = content.Load<Texture2D>("color_map");
			testNormal = content.Load<Texture2D>("null_normal");
			blankTexture = content.Load<Texture2D>("null_color");
			blankSpecular = content.Load<Texture2D>("null_specular");

			meshPrioritySort = new MeshPrioritySort();

			basicEffect = new BasicEffect(device);
			basicEffect.LightingEnabled = false;
			basicEffect.TextureEnabled = false;
			basicEffect.VertexColorEnabled = true;

			boxCorners = new Vector3[8];
		}

		/// <summary>
		/// Set current model effect technique
		/// </summary>
		public void UseTechnique(String technique)
		{
			shaderTechnique = technique;
		}

		/// <summary>
		/// Remove any lights outside of the viewable frustum.
		/// </summary>

		public void CullLights(Scene scene, Camera camera)
		{
			Vector3 lightPosition = Vector3.Zero;
			Vector3 radiusVector = Vector3.Zero;

			// Refresh the list of visible point lights
			scene.visibleLights.Clear();
			BoundingSphere bounds = new BoundingSphere();

			// Pre-cull point lights
			foreach (PointLight light in scene.pointLights)
			{
				lightPosition.X = light.instance.transform.M41;
				lightPosition.Y = light.instance.transform.M42;
				lightPosition.Z = light.instance.transform.M43;

				radiusVector.X = light.instance.transform.M11;
				radiusVector.Y = light.instance.transform.M12;
				radiusVector.Z = light.instance.transform.M13;

				float radius = radiusVector.Length();

				// Create bounding sphere to check which lights are in view

				bounds.Center = lightPosition;
				bounds.Radius = radius;

				if (camera.Frustum.Contains(bounds) != ContainmentType.Disjoint)
				{
					scene.visibleLights.Add(light);
				}
			}
			// Finished culling lights
		}

		/// <summary>
		/// Check for meshes that are outside the view frustum.
		/// </summary>

		public void CullModelMeshes(Scene scene, Camera camera)
		{
			scene.visibleMeshes = 0;
			scene.culledMeshes = 0;

			CullFromModelList(scene, camera, scene.staticModels);
			CullFromModelList(scene, camera, scene.skinnedModels);
			CullFromModelList(scene, camera, scene.blendModels);
		}

		/// <summary>
		/// Clear all visible meshes from all models
		/// </summary>

		public void CullAllModels(Scene scene)
		{
			scene.visibleMeshes = 0;
			scene.culledMeshes = 0;

			// Pre-cull mesh parts
			foreach (InstancedModel instancedModel in scene.staticModels.Values)
			{
				instancedModel.VisibleMeshes.Clear();
			}

			foreach (InstancedModel instancedModel in scene.skinnedModels.Values)
			{
				instancedModel.VisibleMeshes.Clear();
			}

			foreach (InstancedModel instancedModel in scene.blendModels.Values)
			{
				instancedModel.VisibleMeshes.Clear();
			}
		}

		/// <summary>
		/// Remove all scene meshes from the culling list.
		/// </summary>

		public void IgnoreCulling(Scene scene, Camera camera)
		{
			scene.visibleMeshes = 0;
			scene.culledMeshes = 0;

			MakeModelsVisible(scene, camera, scene.staticModels);
			MakeModelsVisible(scene, camera, scene.skinnedModels);
		}

		/// <summary>
		/// Cull meshes from a specified list.
		/// </summary>

		private void CullFromModelList(Scene scene, Camera camera, Dictionary<String, InstancedModel> modelList)
		{
			// Pre-cull mesh parts

			foreach (InstancedModel instancedModel in modelList.Values)
			{
				int meshIndex = 0;
				instancedModel.VisibleMeshes.Clear();
				
				foreach (BoundingBox box in instancedModel.BoundingBoxes)
				{			
					instancedModel.tempBoxes[meshIndex] = box;
					instancedModel.tempBoxes[meshIndex].Min = Vector3.Transform(box.Min, instancedModel.Transform);
					instancedModel.tempBoxes[meshIndex].Max = Vector3.Transform(box.Max, instancedModel.Transform);

					// Add to mesh to visible list if it's contained in the frustum

					if (camera.Frustum.Contains(instancedModel.tempBoxes[meshIndex]) != ContainmentType.Disjoint)
					{
						instancedModel.VisibleMeshes.Add(meshIndex, instancedModel.model.Meshes[meshIndex]);
						scene.visibleMeshes++;
					}
					else
					{
						scene.culledMeshes++;
					}

					// Move position into screen space homoegenous coordinates
					Vector4 source = Vector4.Transform(
						instancedModel.MeshPos[meshIndex], camera.View * camera.Projection);
					instancedModel.ScreenPos[meshIndex] = 
						new Vector2((source.X / source.W + 1f) / 2f, (-source.Y / source.W + 1f) / 2f);
					meshIndex++;
				}
				
				// Finished culling this model
			}
		}

		/// <summary>
		/// Remove culled meshes from a specified list.
		/// </summary>

		public void MakeModelVisible(Dictionary<String, InstancedModel> modelList, String modelName, int meshID)
		{
			int meshIndex = 0;
			bool found = false;

			foreach (ModelMesh mesh in modelList[modelName].model.Meshes)
			{
				if (meshIndex == meshID)
				{
					modelList[modelName].VisibleMeshes.Add(meshIndex, mesh);
					found = true;
				}
				if (found == true) break;
				meshIndex++;
			}
			// Finished adding this model mesh
		}

		/// <summary>
		/// Remove culled meshes from a specified list.
		/// </summary>

		private void MakeModelsVisible(Scene scene, Camera camera,
			Dictionary<String, InstancedModel> modelList)
		{
			// Pre-cull mesh parts
			if (scene.orderedMeshes.Count == 0)
				return;

			int i = 0;
			foreach (KeyValuePair<string, InstancedModel> instancedModel in modelList)
			{
				instancedModel.Value.VisibleMeshes.Clear();
				int meshIndex = 0;

				foreach (ModelMesh mesh in instancedModel.Value.model.Meshes)
				{
					float radius = mesh.BoundingSphere.Radius * instancedModel.Value.scaling.X;
					float distance = Vector3.Distance(
						camera.Position, mesh.BoundingSphere.Center + instancedModel.Value.position);
					if (distance < 0.01f) distance = 0.01f;

					// Set mesh metadata
					scene.orderedMeshes[i].modelName = instancedModel.Key;
					scene.orderedMeshes[i].meshID = meshIndex;
					scene.orderedMeshes[i].priority = radius / distance;

					instancedModel.Value.VisibleMeshes.Add(meshIndex++, mesh);

					i++;
					scene.visibleMeshes++;
				}
				// Finished adding this model
			}

			// Sort the order priority
			scene.orderedMeshes.Sort(meshPrioritySort);
		}

		/// <summary>
		/// Draw the entire scene to the GBuffer
		/// </summary>
		/// <param name="camera"></param>

		public void Draw(Scene scene, Camera camera)
		{
			Viewport viewport = graphicsDevice.Viewport;
			viewport.MinDepth = 0.0f;
			viewport.MaxDepth = 0.9999f;
			graphicsDevice.Viewport = viewport;
			graphicsDevice.RasterizerState = RasterizerState.CullCounterClockwise;

			totalPolys = 0;

			// Update the viewport for proper rendering order

			foreach (InstancedModel instancedModel in scene.staticModels.Values)
			{
				DrawModel(instancedModel, camera, this.shaderTechnique);
			}

			foreach (InstancedModel skinnedModel in scene.skinnedModels.Values)
			{
				DrawModel(skinnedModel, camera, this.shaderTechnique + "Animated");
			}
		}

		/// <summary>
		/// Draw all visible meshes for this model.
		/// </summary>

		private void DrawModel(InstancedModel instancedModel, Camera camera, string tech)
		{
			// Draw the model.			
			instancedModel.model.CopyAbsoluteBoneTransformsTo(instancedModel.boneMatrices);

			foreach (KeyValuePair<int, ModelMesh> mesh in instancedModel.VisibleMeshes)
			{				
				foreach (ModelMeshPart meshPart in mesh.Value.MeshParts)
				{
					graphicsDevice.SetVertexBuffer(meshPart.VertexBuffer, meshPart.VertexOffset);
					graphicsDevice.Indices = meshPart.IndexBuffer;

					// Assign effect and curent technique
					Effect effect = meshPart.Effect;
					effect.CurrentTechnique = effect.Techniques[tech];

					Matrix world = instancedModel.boneMatrices[mesh.Value.ParentBone.Index] * instancedModel.Transform;
					Matrix IWorldView = Matrix.Invert(world * camera.View);
					
					if (instancedModel.animationPlayer != null)
					{
						effect.Parameters["bones"].SetValue(instancedModel.animationPlayer.GetSkinTransforms());
					}

					if (instancedModel.Textures[mesh.Key] == null)
						effect.Parameters["Texture"].SetValue(blankTexture);
					//effect.Parameters["NormalMap"].SetValue(testNormal);
					//effect.Parameters["SpecularMap"].SetValue(blankSpecular);

					effect.Parameters["World"].SetValue(world);
					effect.Parameters["ITWorldView"].SetValue(Matrix.Transpose(IWorldView));
					effect.Parameters["View"].SetValue(camera.View);
					effect.Parameters["Projection"].SetValue(camera.Projection);
					
					for (int i = 0; i < effect.CurrentTechnique.Passes.Count; i++)
					{
						effect.CurrentTechnique.Passes[i].Apply();

						graphicsDevice.DrawIndexedPrimitives(PrimitiveType.TriangleList, 0, 0,
							meshPart.NumVertices, meshPart.StartIndex,
							meshPart.PrimitiveCount);
					}

					totalPolys += meshPart.PrimitiveCount;
				}
			}
			
			// End model rendering
		}

		/// <summary>
		/// Draw with a custom effect
		/// </summary>

		public void Draw(Scene scene, Effect effect, BlendState blendState,
			RasterizerState rasterizerState)
		{
			Viewport viewport = graphicsDevice.Viewport;
			viewport.MinDepth = 0.0f;
			viewport.MaxDepth = 0.9999f;
			graphicsDevice.Viewport = viewport;

			graphicsDevice.DepthStencilState = DepthStencilState.Default; 
			graphicsDevice.RasterizerState = rasterizerState;
			graphicsDevice.BlendState = blendState;

			foreach (InstancedModel instancedModel in scene.staticModels.Values)
			{
				DrawModel(instancedModel, effect, effect.CurrentTechnique.Name);
			}

			foreach (InstancedModel skinnedModel in scene.skinnedModels.Values)
			{
				DrawModel(skinnedModel, effect, effect.CurrentTechnique.Name + "Animated");
			}
			// Finished drawing visible meshes
		}

		/// <summary>
		/// Overloads for drawing custom effects
		/// </summary>	

		public void Draw(Scene scene, Effect effect)
		{
			Draw(scene, effect, BlendState.Opaque, RasterizerState.CullNone);
		}

		public void Draw(Scene scene, Effect effect, BlendState blendState)
		{
			Draw(scene, effect, blendState, RasterizerState.CullNone);
		}

		public void Draw(Scene scene, Effect effect, RasterizerState rasterizerState)
		{
			Draw(scene, effect, BlendState.Opaque, rasterizerState);
		}

		/// <summary>
		/// Draw instanced model with a custom effect
		/// </summary>	

		public void DrawModel(InstancedModel instancedModel, Effect effect, string tech)
		{
			effect.CurrentTechnique = effect.Techniques[tech];
			
			// Draw the model.
			Matrix mainTransform = instancedModel.Transform;
			instancedModel.model.CopyAbsoluteBoneTransformsTo(instancedModel.boneMatrices);

			foreach (KeyValuePair <int, ModelMesh> mesh in instancedModel.VisibleMeshes)
			{
				foreach (ModelMeshPart meshPart in mesh.Value.MeshParts)
				{
					graphicsDevice.SetVertexBuffer(meshPart.VertexBuffer, meshPart.VertexOffset);
					graphicsDevice.Indices = meshPart.IndexBuffer;

					if (instancedModel.animationPlayer != null)
					{
						effect.Parameters["bones"].SetValue(instancedModel.animationPlayer.GetSkinTransforms());
					}

					Matrix world = instancedModel.boneMatrices[mesh.Value.ParentBone.Index] * mainTransform;
					effect.Parameters["World"].SetValue(world);
					effect.Parameters["Texture"].SetValue(instancedModel.Textures[mesh.Key]);
					//effect.Parameters["Texture"].SetValue(meshPart.Effect.Parameters["Texture"].GetValueTexture2D());

					for (int i = 0; i < effect.CurrentTechnique.Passes.Count; i++)
					{
						effect.CurrentTechnique.Passes[i].Apply();

						graphicsDevice.DrawIndexedPrimitives(PrimitiveType.TriangleList, 0, 0,
							meshPart.NumVertices, meshPart.StartIndex,
							meshPart.PrimitiveCount);
					}
				}
				// Finished drawing mesh parts
			}
		}

		/// <summary>
		/// Draw model mesh with a custom effect
		/// </summary>	

		public void DrawModelMesh(InstancedModel instancedModel, int index, Effect effect, string tech)
		{
			effect.CurrentTechnique = effect.Techniques[tech];

			// Draw the model.
			Matrix mainTransform = instancedModel.Transform;
			instancedModel.model.CopyAbsoluteBoneTransformsTo(instancedModel.boneMatrices);

			ModelMesh mesh = instancedModel.model.Meshes[index];

			foreach (ModelMeshPart meshPart in mesh.MeshParts)
			{
				graphicsDevice.SetVertexBuffer(meshPart.VertexBuffer, meshPart.VertexOffset);
				graphicsDevice.Indices = meshPart.IndexBuffer;

				if (instancedModel.animationPlayer != null)
				{
					effect.Parameters["bones"].SetValue(instancedModel.animationPlayer.GetSkinTransforms());
				}

				Matrix world = instancedModel.boneMatrices[mesh.ParentBone.Index] * mainTransform;
				effect.Parameters["World"].SetValue(world);

				for (int i = 0; i < effect.CurrentTechnique.Passes.Count; i++)
				{
					effect.CurrentTechnique.Passes[i].Apply();

					graphicsDevice.DrawIndexedPrimitives(PrimitiveType.TriangleList, 0, 0,
						meshPart.NumVertices, meshPart.StartIndex,
						meshPart.PrimitiveCount);
				}
			}
			// Finished drawing mesh parts
		}

		/// <summary>
		/// Draw the scene's skybox
		/// </summary>

		public void DrawSkybox(Scene scene, Camera camera)
		{
			graphicsDevice.DepthStencilState = DepthStencilState.DepthRead;
			graphicsDevice.RasterizerState = RasterizerState.CullNone;
			
			// Confine the depth range to a very far distance
			Viewport viewport = graphicsDevice.Viewport;
			viewport.MinDepth = 0.999f;
			viewport.MaxDepth = 1.0f;
			graphicsDevice.Viewport = viewport;

			if (scene.Skybox == null)
				return;
			
			// Draw all skybox meshes
			scene.Skybox.VisibleMeshes.Clear();
			int meshIndex = 0;

			foreach (ModelMesh mesh in scene.Skybox.model.Meshes)
			{
				scene.Skybox.VisibleMeshes.Add(meshIndex++, mesh);
			}
			scene.Skybox.Translate(camera.Position).UpdateMatrix();
			DrawModel(scene.Skybox, camera, this.shaderTechnique);
		}

		/// <summary>
		/// Draw all visible bounding boxes
		/// </summary>

		public void DrawBoundingBoxes(Scene scene, Camera camera)
		{
			if (scene.debug == true)
			{
				basicEffect.View = camera.View;
				basicEffect.Projection = camera.Projection;

				foreach (InstancedModel instancedModel in scene.staticModels.Values)
				{
					DrawBoundingBoxes(instancedModel, camera);
				}

				foreach (InstancedModel skinnedModel in scene.skinnedModels.Values)
				{
					DrawBoundingBoxes(skinnedModel, camera);
				}
			}
		}

		/// <summary>
		/// Draw debug bounding box
		/// </summary>
		/// <param name="model"></param>
		/// <param name="camera"></param>

		private void DrawBoundingBoxes(InstancedModel model, Camera camera)
		{
			int meshIndex = 0;

			foreach (BoundingBox box in model.BoundingBoxes)
			{
				// Assign the box corners
				boxCorners[0] = new Vector3(box.Min.X, box.Max.Y, box.Max.Z);
				boxCorners[1] = new Vector3(box.Max.X, box.Max.Y, box.Max.Z); // maximum
				boxCorners[2] = new Vector3(box.Max.X, box.Min.Y, box.Max.Z);
				boxCorners[3] = new Vector3(box.Min.X, box.Min.Y, box.Max.Z);
				boxCorners[4] = new Vector3(box.Min.X, box.Max.Y, box.Min.Z);
				boxCorners[5] = new Vector3(box.Max.X, box.Max.Y, box.Min.Z);
				boxCorners[6] = new Vector3(box.Max.X, box.Min.Y, box.Min.Z);
				boxCorners[7] = new Vector3(box.Min.X, box.Min.Y, box.Min.Z); // minimum

				for (int i = boxCorners.Length; i-- > 0; )
				{
					boxCorners[i] = Vector3.Transform(boxCorners[i], model.Transform);
					model.boxVertices[i] = new VertexPositionColor(boxCorners[i], Color.Cyan);
				}

				// Transform the box with the model's world matrix
				model.tempBoxes[meshIndex].Min = Vector3.Transform(box.Min, model.Transform);
				model.tempBoxes[meshIndex].Max = Vector3.Transform(box.Max, model.Transform);

				// Add to mesh to visible list if it's contained in the frustum
				if (camera.Frustum.Contains(model.tempBoxes[meshIndex]) != ContainmentType.Disjoint)
				{
					basicEffect.World = Matrix.Identity;

					for (int i = 0; i < basicEffect.CurrentTechnique.Passes.Count; i++)
					{
						basicEffect.CurrentTechnique.Passes[i].Apply();
						graphicsDevice.DrawUserIndexedPrimitives<VertexPositionColor>(
							PrimitiveType.LineList, model.boxVertices, 0, 8,
							InstancedModel.bBoxIndices, 0, 12);
					}
				}
				meshIndex++;
			}
			// End box rendering
		}
	}
}
