using System;
using System.Collections.Generic;
using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;

namespace Meteor.Resources
{
	/// <summary>
	/// Camera that follows a target
	/// </summary>
    public class ChaseCamera : Camera
    {
        /// <summary>
        /// Position of object being chased.
        /// </summary>
        public Vector3 ChasePosition
        {
            get { return chasePosition; }
            set { chasePosition = value; }
        }
        private Vector3 chasePosition;

        /// <summary>
        /// Direction the chased object is facing.
        /// </summary>
		public Vector3 chaseDirection;
		public Vector3 up = Vector3.Up;

        /// <summary>
        /// Desired camera position in the chased object's coordinate system.
        /// </summary>
		public Vector3 desiredPositionOffset = new Vector3(0.0f, 30.0f, 60.0f);

        /// <summary>
        /// Desired camera position in world space.
        /// </summary>
        public Vector3 DesiredPosition
        {
            get
            {
                // Ensure correct value even if update has not been called this frame
                UpdateWorldPositions();
                return desiredPosition;
            }
        }
        private Vector3 desiredPosition;

        /// <summary>
        /// Look at point in the chased object's coordinate system.
        /// </summary>
		public Vector3 lookAtOffset = new Vector3(0, 0f, -40.8f);

        /// <summary>
        /// Look at point in world space.
        /// </summary>
        public Vector3 LookAt
        {
            get
            {
                // Ensure correct value even if update has not been called this frame
                UpdateWorldPositions();
                return lookAt;
            }
        }
        private Vector3 lookAt;

        /// <summary>
        /// Physics coefficient which controls the influence of the camera's position
        /// over the spring force. The stiffer the spring, the closer it will stay to
        /// the chased object.
        /// </summary>
		public float stiffness = 10.0f;

        /// <summary>
        /// Physics coefficient which approximates internal friction of the spring.
        /// Sufficient damping will prevent the spring from oscillating infinitely.
        /// </summary>
		public float damping = 0.0f;
        public float mass = 5f;

        /// <summary>
        /// Velocity of camera.
        /// </summary>
        public Vector3 Velocity
        {
            get { return velocity; }
        }
        private Vector3 velocity;

        /// <summary>
        /// Update the values to be chased by the camera
        /// </summary>
        public void UpdateChaseTarget(Vector3 position, Vector3 direction)
        {
            chasePosition = position;
            chaseDirection = direction;
            up = Vector3.Up;
        }	

        /// <summary>
        /// Rebuilds object space values in world space. Invoke before publicly
        /// returning or privately accessing world space values.
        /// </summary>
        private void UpdateWorldPositions()
        {
            // Construct a matrix to transform from object space to worldspace
            Matrix transform = Matrix.Identity;
            transform.Forward = chaseDirection;
            transform.Up = up;
            transform.Right = Vector3.Cross(up, chaseDirection);

            // Calculate desired camera properties in world space
            desiredPosition = ChasePosition +
                Vector3.TransformNormal(desiredPositionOffset, transform);
            lookAt = ChasePosition +
                Vector3.TransformNormal(lookAtOffset, transform);
        }

        /// <summary>
        /// Rebuilds camera's view and projection matricies.
        /// </summary>
        protected override void UpdateMatrices()
        {
			Vector3 direction = Vector3.Normalize(position + LookAt);

			float yaw = (float)Math.Atan2(direction.X, direction.Y);
			float pitch = (float)Math.Atan2(direction.Z,
				Math.Sqrt((direction.X * direction.X) +
						  (direction.Y * direction.Y)));

			worldMatrix = Matrix.Identity;
			view = Matrix.CreateLookAt(position, lookAt, up);

			cameraFrustum.Matrix = view * projection;
        }

        /// <summary>
        /// Forces camera to be at desired position and to stop moving. The is useful
        /// when the chased object is first created or after it has been teleported.
        /// Failing to call this after a large change to the chased object's position
        /// will result in the camera quickly flying across the world.
        /// </summary>
        public void Reset()
        {
            UpdateWorldPositions();

            // Stop motion
            velocity = Vector3.Zero;

            // Force desired position
            position = desiredPosition;
            UpdateMatrices();
        }

        /// <summary>
        /// Same as Reset() except that the camera doesn't change location.
        /// Only lookAt is updated
        /// </summary>

        public void NoFollow()
        {
            UpdateWorldPositions();

            // Stop motion
            velocity = Vector3.Zero;
            UpdateMatrices();
        }

        /// <summary>
        /// Animates the camera from its current position towards the desired offset
        /// behind the chased object. The camera's animation is controlled by a simple
        /// physical spring attached to the camera and anchored to the desired position.
        /// </summary>
        public void Update(GameTime gameTime)
        {
            UpdateWorldPositions();

            float elapsed = (float)gameTime.ElapsedGameTime.TotalSeconds;

            // Calculate spring force
            Vector3 stretch = position - desiredPosition;
            position -= stretch * (elapsed) * stiffness;

            UpdateMatrices();
        }
    }
}