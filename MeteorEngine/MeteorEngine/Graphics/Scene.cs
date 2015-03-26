using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Content;
using Microsoft.Xna.Framework.Graphics;
using Meteor.Rendering;
using Meteor.Resources;
using SkinnedModel;

namespace Meteor.Resources
{
    public class Scene
    {
		/// For creating dynamic content
		GraphicsDevice device;

        /// For loading scene content
        ContentManager content;

        /// List of models in the scene
        public Dictionary <String, InstancedModel> staticModels;
		public Dictionary <String, InstancedModel> skinnedModels;
		public Dictionary <String, InstancedModel> blendModels;

		/// Directional light list
		public List<DirectionLight> directionalLights = new List<DirectionLight>();

		/// Point light position to setup current lights
		public List<PointLight> pointLights = new List<PointLight>();

		/// Instanced data used for rendering
		public List<PointLight> visibleLights = new List<PointLight>();

		/// Ambient lighting
		public float ambientLight = 0.0f;

		public List<PointLight> VisiblePointLights
		{
			get
			{
				return visibleLights;
			}
		}

		public int totalLights
		{
			get
			{
				return visibleLights.Count;
			}
		}

		public class OrderedMeshData
		{
			public string modelName;
			public int meshID;
			public float priority;
		};

		public List<OrderedMeshData> orderedMeshes;

		/// Vertex buffer to hold the instance data
		public DynamicVertexBuffer boxVertexBuffer;
		public VertexPositionColor[] boxPrimitiveList;

		/// Skybox mesh
		InstancedModel skyboxModel;

		public InstancedModel Skybox
		{
			get
			{
				return skyboxModel;
			}
		}

		/// Scene rendering stats
		public int totalPolys;
		public bool debug = false;
		public int visibleMeshes = 0;
		public int culledMeshes = 0;
		public int drawCalls = 0;

        public Scene(ContentManager content, GraphicsDevice device)
        {
            this.content = content;
			Initialize(device);
        }

		public Scene(ContentManager content)
		{
			this.content = content;
			Initialize(null);
		}

		private void Initialize(GraphicsDevice device)
		{
			this.device = device;

			staticModels = new Dictionary<string, InstancedModel>();
			skinnedModels = new Dictionary<string, InstancedModel>();
			blendModels = new Dictionary<string, InstancedModel>();

			orderedMeshes = new List<OrderedMeshData>();
		}

		/// <summary>
		/// Load any additional scene components
		/// </summary>

		public void LoadContent() {}

		/// <summary>
		/// Helper to add a new point light to the scene and return a reference to it
		/// </summary>
		
		public PointLight AddPointLight(Vector3 position, Color color, float radius, 
			float intensity)
		{
			PointLight light = new PointLight(position, color, radius, intensity);
			pointLights.Add(light);
			
			return pointLights.Last();
		}

        /// <summary>
        /// Helper to add a new model to the scene with 
        /// the same name key as the file for the model
        /// </summary>
		
        public InstancedModel AddModel(String modelPath, String directory)
        {
            staticModels.Add(modelPath, 
				new InstancedModel(modelPath, directory, content, device));
			for(int i = 0; i < staticModels[modelPath].TotalMeshes; i++)
			{
				orderedMeshes.Add(new OrderedMeshData());
			}

			return staticModels[modelPath];
        }

		public InstancedModel AddModelName(String modelName, String modelPath)
		{
			staticModels.Add(modelName,
				new InstancedModel(modelPath, modelPath, content, device));
			for (int i = 0; i < staticModels[modelName].TotalMeshes; i++)
			{
				orderedMeshes.Add(new OrderedMeshData());
			}

			return staticModels[modelName];
		}

		public InstancedModel AddModel(String modelPath)
		{
			return AddModel(modelPath, modelPath);
		}

		/// <summary>
		/// Helper to add a new skinned model to the scene with 
		/// the same name key as the file for the model
		/// </summary>

		public InstancedModel AddSkinnedModel(String modelPath)
		{
			skinnedModels.Add(modelPath, new InstancedModel(modelPath, modelPath, content, device));
			InstancedModel instancedModel = skinnedModels[modelPath];
			
			// Look up our custom skinning information.
			SkinningData skinningData = instancedModel.model.Tag as SkinningData;
			
			if (skinningData == null)
				throw new InvalidOperationException
					("This model does not contain a SkinningData tag.");
			
			// Create an animation player, and start decoding an animation clip.
			instancedModel.animationPlayer = new AnimationPlayer(skinningData);

			AnimationClip clip = skinningData.AnimationClips["Take 001"];
			instancedModel.animationPlayer.StartClip(clip);
			
			return instancedModel;
		}

		/// <summary>
		/// Helper to add a skybox which will be added to a special Skybox list
		/// </summary>

		public InstancedModel AddSkybox(String modelPath)
		{
			skyboxModel = new InstancedModel(modelPath, modelPath, content, device);
			return skyboxModel;
		}

		/// <summary>
		/// Helper to add a skybox which will be added to a special Skybox list
		/// </summary>

		public InstancedModel AddBlendModel(String modelPath)
		{
			blendModels.Add(modelPath, new InstancedModel(modelPath, modelPath, content, device));
			InstancedModel instancedModel = blendModels[modelPath];

			return blendModels[modelPath];
		}

        /// <summary>
        /// Return a model from the list given the same key
        /// </summary>
		/// 
        public InstancedModel Model(String modelKey)
        {
			if (staticModels.ContainsKey(modelKey))
			{
				return staticModels[modelKey];
			}
			else
			{
				return skinnedModels[modelKey];
			}
        }

		public void Update(GameTime gameTime)
		{
			drawCalls = 0;

			foreach (InstancedModel skinnedModel in skinnedModels.Values)
			{		
				if (skinnedModel.animationPlayer != null)
				{
					//skinnedModel.boneMatrices = skinnedModel.animationPlayer.GetSkinTransforms();
					skinnedModel.animationPlayer.Update(gameTime.ElapsedGameTime, true, Matrix.Identity);
					
					float currentAnimTime = (float)gameTime.TotalGameTime.TotalSeconds;
					
					skinnedModel.Rotate(0, MathHelper.ToDegrees(-currentAnimTime / 1.7f + MathHelper.Pi), 0).
						Translate(new Vector3(
						(float)Math.Cos(currentAnimTime / 1.7f) * 70 + 20, skinnedModel.position.Y,
						(float)Math.Sin(currentAnimTime / 1.7f) * 70)).UpdateMatrix();
					
				}
				// Finished updating mesh
			}
		}

    }
}