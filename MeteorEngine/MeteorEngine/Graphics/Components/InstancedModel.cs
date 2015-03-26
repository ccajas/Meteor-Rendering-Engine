using System;
using System.Collections.Generic;
using System.Text;
using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Content;
using Microsoft.Xna.Framework.Graphics;
using SkinnedModel;

namespace Meteor.Resources
{
    public class InstancedModel
    {
        /// Model representing the object
        public Model model;

        /// Model's main normal texture
        public List<Texture2D> modelTextures;

		public List<Texture2D> Textures
		{
			get
			{
				return modelTextures;
			}
		}

        /// Transformation matrix for the model
        Matrix modelMatrix;

		/// Translation vector
		public Vector3 position;

		/// Scaling vector
		public Vector3 scaling;

		/// Rotation and quaternion components
		public Vector3 rotation;
		public Quaternion quaternion;

		/// Number of meshes for this model
		int totalMeshes;

		public int TotalMeshes
		{
			get { return totalMeshes; }
		}

		/// List of visible meshes for this model
		Dictionary<int, ModelMesh> visibleMeshes;
		public Dictionary<int, ModelMesh> VisibleMeshes
		{
			get { return visibleMeshes; }
		}

		/// List to keep bounding boxes for all model meshes
		BoundingBox[] boundingBoxes;
		public BoundingBox[] BoundingBoxes
		{
			get { return boundingBoxes; }
		}

		public BoundingBox[] tempBoxes;
		public Vector3[] tempBoxPos;

		/// List to keep position of meshes
		Vector3[] meshPos;
		public Vector3[] MeshPos
		{
			get { return meshPos; }
		}

		/// List to keep screen space locations of meshes
		Vector2[] screenPos;
		public Vector2[] ScreenPos
		{
			get { return screenPos; }
		}

		Vector2[] maxUV;
		Vector2[] minUV;

		// Initialize an array of indices of type short.
		public static readonly short[] bBoxIndices = {
			0, 1, 1, 2, 2, 3, 3, 0,
			4, 5, 5, 6, 6, 7, 7, 4,
			0, 4, 1, 5, 2, 6, 3, 7
		};

		public VertexPositionColor[] boxVertices;

		/// The instances this model has
		List <EntityInstance> instances;

		/// Holds references to instances updateable for the camera
		List <EntityInstance> visibleInstances;

		/// Number of visible instances for current frame
		int totalVisible;

		public int TotalVisible
		{
			get
			{
				return totalVisible;
			}
		}

		/// Total instances
		int initialInstanceCount;

		/// Animator to link with a skinned mesh
		public AnimationPlayer animationPlayer;

		public Matrix[] boneMatrices;

        /// Model's contentManager
        ContentManager content;

        /// <summary>
        /// Load a model from the ContentManager from a file
        /// </summary>
        /// <param name="modelName">Model's file name</param>
        /// <param name="content">The program's ContentManger</param>

		public InstancedModel(string modelName, string directory, ContentManager content,
			GraphicsDevice device)
		{
            this.content = content;

            try
            {
				String path = "Models\\" + directory + "\\" + modelName;
				model = content.Load<Model>(path);
            }
			catch (Exception e)
            {
                String message = e.Message;
				String path = "Models\\" + modelName;
				model = content.Load<Model>(path);
            }

			totalMeshes = 0;
			totalVisible = 0;
			scaling = Vector3.One;
			animationPlayer = null;

			// Set up model data
			modelTextures = new List<Texture2D>();
			visibleMeshes = new Dictionary<int, ModelMesh>(model.Meshes.Count);

			boundingBoxes = new BoundingBox[model.Meshes.Count];
			tempBoxes = new BoundingBox[model.Meshes.Count];
			boxVertices = new VertexPositionColor[BoundingBox.CornerCount];

			meshPos = new Vector3[model.Meshes.Count];
			screenPos = new Vector2[model.Meshes.Count];
			tempBoxPos = new Vector3[model.Meshes.Count];

			boneMatrices = new Matrix[model.Bones.Count];
			model.CopyAbsoluteBoneTransformsTo(boneMatrices);

			maxUV = new Vector2[model.Meshes.Count];
			minUV = new Vector2[model.Meshes.Count];
			position = Vector3.Zero;
			rotation = Vector3.Zero;

			modelMatrix = Matrix.Identity;
			quaternion = Quaternion.Identity;

			// Extract textures and create bounding boxes

			foreach (ModelMesh mesh in model.Meshes)
			{
				Matrix meshTransform = boneMatrices[mesh.ParentBone.Index];
				boundingBoxes[totalMeshes] = BuildBoundingBox(mesh, meshTransform);

				Vector2[] UVs = GetUVExtents(mesh);
				maxUV[totalMeshes] = UVs[0];
				minUV[totalMeshes] = UVs[1];

				foreach (ModelMeshPart part in mesh.MeshParts)
				{
					// Create the texture on the fly
					Vector2 size = 16 * (maxUV[totalMeshes] - minUV[totalMeshes]);
					size.X = (size.X < 1) ? 1 : size.X;
					size.Y = (size.Y < 1) ? 1 : size.Y;

					Texture2D blankTexture = new Texture2D(device, (int)size.X, (int)size.Y);
					Color[] mPixels = new Color[(int)size.X * (int)size.Y];

					for (int row = 0; row < size.Y - 1; row++)
					{
						for (int col = 0; col < size.X - 1; col++)
						{
							mPixels[row * (int)size.X + col] = Color.White;
							if ((col % 2) + (row % 2) == 1)
								mPixels[row * (int)size.X + col] = Color.Red;
						}
					}
					blankTexture.SetData(mPixels);

					modelTextures.Add(part.Effect.Parameters["Texture"].GetValueTexture2D());
					//part.Effect.Parameters["Texture"].SetValue(blankTexture);
				}
				totalMeshes++;
			}

			// Default number of instances
			initialInstanceCount = 1;
			visibleInstances = new List<EntityInstance>();

			// Initialize the list of instances
			instances = new List<EntityInstance>();		
			instances.Add(new EntityInstance());
        }

		/// <summary>
		/// Create a bounding box for each model mesh
		/// </summary>

		private BoundingBox BuildBoundingBox(ModelMesh mesh, Matrix meshTransform)
		{
			// Create initial variables to hold min and max xyz values for the mesh
			Vector3 meshMax = new Vector3(float.MinValue);
			Vector3 meshMin = new Vector3(float.MaxValue);
			
			foreach (ModelMeshPart part in mesh.MeshParts)
			{
				// The stride is how big, in bytes, one vertex is in the vertex buffer
				// We have to use this as we do not know the make up of the vertex
				int stride = part.VertexBuffer.VertexDeclaration.VertexStride;

				VertexPositionNormalTexture[] vertexData = new VertexPositionNormalTexture[part.NumVertices];
				part.VertexBuffer.GetData(part.VertexOffset * stride, vertexData, 0, part.NumVertices, stride);

				// Find minimum and maximum xyz values for this mesh part
				Vector3 vertPosition = new Vector3();
				Vector2 vertUV = new Vector2();

				for (int i = 0; i < vertexData.Length; i++)
				{
					vertPosition = vertexData[i].Position;
					vertUV = vertexData[i].TextureCoordinate;

					// update our values from this vertex
					meshMin = Vector3.Min(meshMin, vertPosition);
					meshMax = Vector3.Max(meshMax, vertPosition);
				}
			}

			// transform by mesh bone transforms
			meshMin = Vector3.Transform(meshMin, meshTransform);
			meshMax = Vector3.Transform(meshMax, meshTransform);

			// Create the bounding box
			BoundingBox box = new BoundingBox(meshMin, meshMax);
			return box;
		}

		/// <summary>
		/// Calculate the UV extents
		/// </summary>

		private Vector2[] GetUVExtents(ModelMesh mesh)
		{
			// Create initial variables to hold min and max xy values for the mesh
			Vector2[] uvMinMax = new Vector2[2];
			uvMinMax[0] = new Vector2(float.MinValue);
			uvMinMax[1] = new Vector2(float.MaxValue);

			foreach (ModelMeshPart part in mesh.MeshParts)
			{
				// The stride is how big, in bytes, one vertex is in the vertex buffer
				// We have to use this as we do not know the make up of the vertex
				int stride = part.VertexBuffer.VertexDeclaration.VertexStride;

				VertexPositionNormalTexture[] vertexData = new VertexPositionNormalTexture[part.NumVertices];
				part.VertexBuffer.GetData(part.VertexOffset * stride, vertexData, 0, part.NumVertices, stride);

				// Find minimum and maximum xyz values for this mesh part
				Vector2 vertUV = new Vector2();

				for (int i = 0; i < vertexData.Length; i++)
				{
					vertUV = vertexData[i].TextureCoordinate;

					// update our values from this vertex
					uvMinMax[0] = Vector2.Max(uvMinMax[0], vertUV);
					uvMinMax[1] = Vector2.Min(uvMinMax[1], vertUV);
				}
			}

			return uvMinMax;
		}

		/// <summary>
		/// Helper to add mesh instances
		/// Called: As needed
		/// <summary>

		public void AddInstance(Matrix transform)
		{
			initialInstanceCount++;
			instances.Add(new EntityInstance(transform));

			//Array.Resize(ref instanceTransforms, instances.Count());
		}

		/// <summary>
		/// Helpers to translate model and chain to another method
		/// </summary>

		public InstancedModel Translate(float x, float y, float z)
		{
			position = new Vector3(x, y, z);
			return this;
		}

		public InstancedModel Translate(Vector3 translate)
		{
			position = translate;
			return this;
		}

		/// <summary>
		/// Helpers to scale model and chain to another method
		/// </summary>

		public InstancedModel Scale(float x, float y, float z)
		{
			scaling = new Vector3(x, y, z);
			return this;
		}

		public InstancedModel Scale(float scale)
		{
			scaling = new Vector3(scale);
			return this;
		}

		/// <summary>
		/// Helpers to rotate model and chain to another method
		/// </summary>

		public InstancedModel Rotate(float x, float y, float z)
		{
			x = MathHelper.ToRadians(x);
			y = MathHelper.ToRadians(y);
			z = MathHelper.ToRadians(z);

			rotation = new Vector3(x, y, z);
			quaternion = Quaternion.CreateFromYawPitchRoll(y, x, z);
			return this;
		}

		public InstancedModel Rotate(Quaternion quat)
		{
			quaternion = quat;
			return this;
		}

		/// <summary>
		/// Update model's world matrix based on scale, rotation, and translation
		/// </summary>
		
		public Matrix UpdateMatrix()
		{
			modelMatrix = Matrix.CreateScale(scaling) * 
				Matrix.CreateFromQuaternion(quaternion) *
				Matrix.CreateTranslation(position);

			// Recalculate the screen space position of this mesh
			for (int i = 0; i < totalMeshes; i++)
			{
				tempBoxes[i] = boundingBoxes[i];
				tempBoxes[i].Min = Vector3.Transform(boundingBoxes[i].Min, Transform);
				tempBoxes[i].Max = Vector3.Transform(boundingBoxes[i].Max, Transform);

				MeshPos[i] = (tempBoxes[i].Max + tempBoxes[i].Min) / 2f;
			}

			return modelMatrix;
		}

        public Matrix Transform
        {
            get { return modelMatrix; }
			set { modelMatrix = value; }
        }
    }
}
