using System;
using System.Collections.Generic;
using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Input;
using Microsoft.Xna.Framework.Graphics;

namespace Meteor.Resources
{
    /// <summary>
    /// Controllable camera class
    /// </summary>
    public class Camera
    {
		protected float cameraArc = 0;
		protected float targetArc = 0;

        public float CameraArc
        {
            get { return cameraArc; }
        }

		protected float cameraRotation = -90;
		protected float targetRotation = -90;

        public float CameraRotation
        {
            get { return cameraRotation; }
        }

		protected Matrix worldMatrix;
		public Matrix WorldMatrix
		{
			get { return worldMatrix; }
		}

		protected Matrix view;
		public Matrix View
		{
			get { return view; }
			set { view = value; }
		}

		protected Matrix projection;
		public Matrix Projection
		{
			get { return projection; }
			set { projection = value; }
		}

		protected Matrix oldView;
		public Matrix OldView
		{
			get { return oldView; }
		}

		protected Matrix oldProjection;
		public Matrix OldProjection
		{
			get { return oldProjection; }
		}

		protected Vector3 position;
        public Vector3 Position
        {
            get { return position; }
        }

		protected BoundingFrustum cameraFrustum;
		public BoundingFrustum Frustum
		{
			get { return cameraFrustum; }
			set { cameraFrustum = value; }
		}

		public Vector3[] frustumCorners;

		protected Vector2 viewAspect;
		public Vector2 ViewAspect
		{
			get { return viewAspect; }
		}

		protected float fieldOfView;
		public float FieldOfView
		{
			get { return fieldOfView; }
		}

		protected float aspectRatio;
		public float AspectRatio
		{
			get { return aspectRatio; }
		}

		/// Default position to keep the mouse pointer centered
		protected Vector2 viewCenter;

        public float nearPlaneDistance = 1f;
        public float farPlaneDistance = 1000.0f;
		public float nearSplitPlaneDistance;
		public float farSplitPlaneDistance;

		public Vector2 GetFrustumSplit(int split, int numSplits, float lambda = 0.75f)
		{
			float farPlane = farPlaneDistance;
			split = (split > numSplits) ? numSplits : split;

			// CLi = n*(f/n)^(i/numsplits)
			// CUi = n + (f-n)*(i/numsplits)
			// Ci = CLi*(lambda) + CUi*(1-lambda)

			float fLog = nearPlaneDistance *
				(float)Math.Pow((farPlane / nearPlaneDistance), (split + 1) / (float)numSplits);
			float fLinear = nearPlaneDistance + (farPlane - nearPlaneDistance) * 
				((split + 1) / (float)numSplits);

			// make sure border values are right
			farSplitPlaneDistance = fLog * lambda + fLinear * (1 - lambda);

			fLog = nearPlaneDistance *
				(float)Math.Pow((farPlane / nearPlaneDistance), split / (float)numSplits);
			fLinear = nearPlaneDistance + (farPlane - nearPlaneDistance) *
				(split / (float)numSplits);

			nearSplitPlaneDistance = fLog * lambda + fLinear * (1 - lambda); //nearPlaneDistance;

			return new Vector2(nearSplitPlaneDistance * 0.95f, farSplitPlaneDistance);
		}

        public Camera()
        {
            position.Y = 4f;

			nearSplitPlaneDistance = nearPlaneDistance;
			farSplitPlaneDistance = farPlaneDistance;
        }

		public Camera(Vector3 pos, Vector2 orientation)
		{
			position = pos;

			cameraRotation = orientation.X;
			cameraArc = orientation.Y;

			targetRotation = orientation.X; // yaw
			targetArc = orientation.Y; // pitch

			nearSplitPlaneDistance = nearPlaneDistance;
			farSplitPlaneDistance = farPlaneDistance;
		}

        /// <summary>
        /// Allows the game component to perform any initialization it needs to before starting
        /// to run.  This is where it can query for any required services and load content.
        /// </summary>
        public void Initialize(float width, float height)
        {
            // Add your initialization code here
			viewAspect.X = (int)width;
			viewAspect.Y = (int)height;
			fieldOfView = MathHelper.PiOver4;

			cameraFrustum = new BoundingFrustum(Matrix.Identity);
			frustumCorners = new Vector3[8];
			worldMatrix = Matrix.Identity;

			viewCenter = new Vector2(width/2f, height/2f);

			UpdateProjection();
        }

        /// <summary>
        /// Update the near and far clipping planes of the viewport
        /// </summary>
		public void UpdateNearFar(Vector2 clipPlanes)
        {
            nearPlaneDistance = clipPlanes.X;
            farPlaneDistance = clipPlanes.Y;
            UpdateProjection();
        }

		public void SetLookAt(Vector3 lookAt)
		{
			position = lookAt;
		}

		public void SetOrientation(Vector2 orientation)
		{
			targetRotation = orientation.X; // yaw
			targetArc = orientation.Y; // pitch			
		}

		public virtual void Update()
		{
			oldView = view;
			oldProjection = projection;

			UpdateMatrices();
		}

        /// <summary>
        /// Set the camera's matrix transformations
        /// </summary>
		protected virtual void UpdateMatrices()
        {
            view = Matrix.CreateLookAt(position, position + worldMatrix.Forward, worldMatrix.Up);
			cameraFrustum.Matrix = view * projection;
        }

        /// <summary>
        /// Set the camera's projection matrix
        /// </summary>
		protected void UpdateProjection()
        {
			aspectRatio = (float)viewAspect.X / (float)viewAspect.Y;
            projection = Matrix.CreatePerspectiveFieldOfView(
				fieldOfView, aspectRatio, nearPlaneDistance, farPlaneDistance);
        }
	}

	/// <summary>
	/// Gets an array of points for a camera's BoundingFrustum.
	/// </summary>

	public static partial class BoundingFrustumExtention
	{
		public static Vector3[] GetCorners(this BoundingFrustum frustum, Camera camera)
		{
			// Calculate the near and far plane centers
			Vector3 nearPlaneCenter = camera.Position +
				Vector3.Normalize(camera.WorldMatrix.Forward) * camera.nearSplitPlaneDistance;
			Vector3 farPlaneCenter = camera.Position +
				Vector3.Normalize(camera.WorldMatrix.Forward) * camera.farSplitPlaneDistance;

			// Get the vertical and horizontal extent locations from the center
			float nearExtentDistance = (float)Math.Tan(camera.FieldOfView / 2f) * camera.nearSplitPlaneDistance;
			Vector3 nearExtentY = nearExtentDistance * Vector3.Up;
			Vector3 nearExtentX = nearExtentDistance * camera.AspectRatio * camera.WorldMatrix.Left;

			float farExtentDistance = (float)Math.Tan(camera.FieldOfView / 2f) * camera.farSplitPlaneDistance;
			Vector3 farExtentY = farExtentDistance * Vector3.Up;
			Vector3 farExtentX = farExtentDistance * camera.AspectRatio * camera.WorldMatrix.Left;

			// Calculate the frustum corners by adding/subtracting the extents
			// Starting clockwise and from the near plane first
			camera.frustumCorners[0] = nearPlaneCenter + nearExtentY - nearExtentX;
			camera.frustumCorners[1] = nearPlaneCenter + nearExtentY + nearExtentX;
			camera.frustumCorners[2] = nearPlaneCenter - nearExtentY + nearExtentX;
			camera.frustumCorners[3] = nearPlaneCenter - nearExtentY - nearExtentX;

			camera.frustumCorners[4] = farPlaneCenter + farExtentY - farExtentX;
			camera.frustumCorners[5] = farPlaneCenter + farExtentY + farExtentX;
			camera.frustumCorners[6] = farPlaneCenter - farExtentY + farExtentX;
			camera.frustumCorners[7] = farPlaneCenter - farExtentY - farExtentX;

			return camera.frustumCorners;
		}
	}
}


