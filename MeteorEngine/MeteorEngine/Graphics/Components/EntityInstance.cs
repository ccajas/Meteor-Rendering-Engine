
using System;
using System.Collections;
using Microsoft.Xna.Framework;

namespace Meteor.Resources
{
	/// <summary>
	/// Class which holds and sets up matrix and color info for a mesh instance.
	/// It also helps update the position of the mesh's BoundingSphere.
	/// </summary>
	/// 
	public class EntityInstance
	{
		#region Fields

		/// Mesh instance matrix
		Matrix transform;

		/// Scaling component of the instance
		Vector3 scale;

		/// The largest factor to scale by
		public float largestScale;

		/// Stores all the vertex declaration data for this instance
		public struct InstanceData
		{
			public Matrix transform;
			public uint color;
		}

		/// Check whether this instance is closer or farther than another instance
		public int CompareTo(object other)
		{
			EntityInstance otherInstance = (EntityInstance)other;
			return -(distance.CompareTo(otherInstance.distance));
		}

		public InstanceData instanceData;

		/// Color associated with this instance
		public int color;

		/// World position of this instance
		public Vector3 position;

		/// Distance to a world position
		public float distance = 0f;

		/// Gets the instance's transform matrix
		public Matrix Transform
		{
			get
			{
				return transform;
			}
		}

		static Random random = new Random(256);

		#endregion

		/// Constructor sets identity matrix as default
		public EntityInstance()
		{
			transform = Matrix.Identity;

			int r = random.Next() << 24;
			int g = random.Next() << 16;
			int b = random.Next() << 8;

			scale = new Vector3(1, 1, 1);
			largestScale = 1f;
			instanceData.color = 0xffffffff; //(255 << 24) + r + g + b;
		}

		/// New instance with an Entity and transform matrix
		public EntityInstance(Matrix instanceTransform)
		{
			transform = instanceTransform;

			int r = random.Next() << 16;
			int g = random.Next() << 8;
			int b = random.Next();

			instanceData.color = 0xffffffff; // (255 << 24) + r + g + b;
		}

		/// <summary>
		/// Automatically updates the position of the instance with an 
		/// optional pre-defined movement pattern
		/// </summary>
		public void Update(GameTime gameTime)
		{
			//float time = (float)gameTime.TotalGameTime.TotalSeconds;

			position = Transform.Translation;
		}

		/// <summary>
		/// Set the distance to a particular world position
		/// </summary>
		public void UpdateDistanceTo(Vector3 dest)
		{
			distance = Vector3.Distance(position, dest);
		}

		/// <summary>
		/// Helper for picking a random number inside the specified range
		/// </summary>
		static float RandomNumberBetween(float min, float max)
		{
			return MathHelper.Lerp(min, max, (float)random.NextDouble());
		}
	}
}
