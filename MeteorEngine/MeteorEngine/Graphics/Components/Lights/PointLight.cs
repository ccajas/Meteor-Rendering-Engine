using System;
using System.Collections.Generic;
using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Content;
using Microsoft.Xna.Framework.Graphics;
using System.Diagnostics;

namespace Meteor.Resources
{
    public struct PointLight
    {
        /// Light's position
        public Vector3 position;

        /// Radius of the light's extent
        public float radius;

        /// Intensity of the light
        public float intensity;

        /// Color of the light
        public Color color;

		/// Stores all the vertex declaration data for this
		/// point light instance
		public struct InstanceData
		{
			public Matrix transform;
			public uint color;
		}

		public InstanceData instance;

        /// <summary>
        /// Set one point light and add it to the instance data
        /// </summary>

        public PointLight(Vector3 lightPosition, Color color,
            float radius, float intensity)
        {
            this.radius = radius;
            this.intensity = intensity;
            this.position = lightPosition;
			this.color = color;

            // Compute the light's world matrix
            Matrix sphereWorldMatrix = Matrix.CreateScale(radius) * 
				Matrix.CreateTranslation(lightPosition);

            instance.transform = sphereWorldMatrix;
			instance.color = color.PackedValue;
        }

        public void Update()
        {
            // Compute the light's world matrix
            Matrix sphereWorldMatrix = Matrix.CreateScale(radius) *
                Matrix.CreateTranslation(position);

			instance.transform = sphereWorldMatrix;
        }
    }
}
