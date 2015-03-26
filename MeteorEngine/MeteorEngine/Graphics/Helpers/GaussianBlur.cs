
using System;
using System.Collections.Generic;
using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Content;

namespace Meteor.Resources
{
	class GaussianBlur
	{
		// This will slightly blur the depth maps. 
		// If you want a larger blur change the sample_count to a higher odd number.
		int sampleCount;

		// Gaussian offsets and weights
		public Vector4[] sampleOffsetsH;
		public Vector4[] sampleOffsetsV;

		public float[] sampleWeightsH;
		public float[] sampleWeightsV;

		float stepDownsizeFactor;

		public GaussianBlur(int dx, int dy, float step, Effect blurEffect)
		{
			// Look up the sample weight and offset effect parameters.
			EffectParameter weightsParameter;
			weightsParameter = blurEffect.Parameters["sampleWeights"];
			stepDownsizeFactor = (step < 0.0001f) ? 1 : step;

			// Look up how many samples our gaussian blur effect supports.
			// This amount is set in the GaussianBlur.fx effect file.
			sampleCount = weightsParameter.Elements.Count;

			// Set up Guassian sample data
			sampleOffsetsH = new Vector4[sampleCount];
			sampleOffsetsV = new Vector4[sampleCount];

			sampleWeightsH = new float[sampleCount];
			sampleWeightsV = new float[sampleCount];

			// Initialize effect parameters
			int width = dx - sampleCount;
			int height = dy - sampleCount;

			SetBlurEffectParameters(blurEffect, 1.0f / (float)width, 0, sampleOffsetsH, sampleWeightsH);
			SetBlurEffectParameters(blurEffect, 0, 1.0f / (float)height, sampleOffsetsV, sampleWeightsV);
        }

		/// <summary>
		/// Blur parameter calculation, taken from GraphicsRunner's Dual-Paraboloid Variance Shadow Mapping
		/// example. Computes sample weightings and texture coordinate offsets for one pass of a separable 
		/// Gaussian blur filter.
		/// </summary>
		private void SetBlurEffectParameters(Effect blurEffect, float dx, float dy,
			Vector4[] offsets, float[] weights)
		{
			blurEffect.Parameters["stepDownsizeFactor"].SetValue(stepDownsizeFactor);

			// The first sample always has a zero offset.
			weights[0] = ComputeGaussian(0);
			offsets[0] = new Vector4();

			// Maintain a sum of all the weighting values.
			float totalWeights = weights[0];

			// Add pairs of additional sample taps, positioned
			// along a line in both directions from the center.
			for (int i = 0; i < sampleCount / 2; i++)
			{
				// Store weights for the positive and negative taps.
				float weight = ComputeGaussian(i + 1);

				weights[i * 2 + 1] = weight;
				weights[i * 2 + 2] = weight;

				totalWeights += weight * 2;

				// To get the maximum amount of blurring from a limited number of
				// pixel shader samples, we take advantage of the bilinear filtering
				// hardware inside the texture fetch unit. If we position our texture
				// coordinates exactly halfway between two texels, the filtering unit
				// will average them for us, giving two samples for the price of one.
				// This allows us to step in units of two texels per sample, rather
				// than just one at a time. The 1.5 offset kicks things off by
				// positioning us nicely in between two texels.
				float sampleOffset = i * 2 + 1.5f;

				Vector4 delta = new Vector4(dx, dy, 1.0f, 1.0f) * (sampleOffset / stepDownsizeFactor);

				// Store texture coordinate offsets for the positive and negative taps.
				offsets[i * 2 + 1] = delta;
				offsets[i * 2 + 2] = -delta;
			}

			// Normalize the list of sample weightings, so they will always sum to one.
			for (int i = 0; i < sampleCount; i++)
			{
				weights[i] /= totalWeights;
			}
		}

		/// <summary>
		/// Evaluates a single point on the gaussian falloff curve.
		/// Used for setting up the blur filter weightings.
		/// </summary>
		private float ComputeGaussian(float n)
		{
			//theta = the blur amount
			float theta = 4.0f;

			return (float)((1.0 / Math.Sqrt(2 * Math.PI * theta)) *
				Math.Exp(-(n * n) / (2 * theta * theta)));
		}
	}
}