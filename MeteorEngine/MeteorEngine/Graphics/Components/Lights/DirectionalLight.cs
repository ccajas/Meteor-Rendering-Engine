using System;
using System.Collections.Generic;
using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Content;
using Microsoft.Xna.Framework.Graphics;

namespace Meteor.Resources
{
    public struct DirectionLight
    {
        /// Light's direction
        public Vector3 direction;

        /// Color of the light
        public Color color;

		/// Intensity of the light
		public float intensity;

		/// Determines if it's used for shadow casting
		public bool castsShadows;

        /// <summary>
        /// Set one directional light
        /// </summary>

        public DirectionLight(Vector3 lightDirection, Color lightColor)
        {
            direction = lightDirection;
            color = lightColor;
			castsShadows = false;
			intensity = 1f;
        }

		public Matrix LightView(Vector3 position)
		{
			return Matrix.CreateLookAt(position, position + Vector3.Normalize(direction), Vector3.Up);
		}

		public Matrix LightOrthographic(float size, float distance)
		{
			return Matrix.CreateOrthographic(size, size, distance / 1000f, distance);
		}
    }
}
