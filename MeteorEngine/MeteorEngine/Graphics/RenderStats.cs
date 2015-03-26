using System;
using System.Collections.Generic;
using System.Diagnostics;
using Microsoft.Xna.Framework;

namespace Meteor.Resources
{
	public class RenderStats
	{
		/// Framerate measuring
		float frameCounter;
		public float frameRate;
		public long totalFrames;

		/// Measure how much time since past update
		TimeSpan elapsedTime;

		/// Specific time to update at certain intervals
		TimeSpan frameStepTime;

		/// Timer to track rendering time
		Stopwatch gpuWatch;
		double gpuTime;

		public double GpuTime
		{
			get { return gpuTime; }
		}

		public RenderStats()
		{
			gpuWatch = new Stopwatch();
		}

		/// <summary>
		/// Update the frames per second counter.
		/// </summary>
		/// <param name="gameTime"></param>

		public void Update(GameTime gameTime)
		{
			gpuWatch.Stop();
			gpuTime = gpuWatch.Elapsed.TotalMilliseconds;

			// Measure our framerate every half second
			elapsedTime += gameTime.ElapsedGameTime;
			frameStepTime += gameTime.TotalGameTime;

			if (elapsedTime > TimeSpan.FromSeconds(0.5))
			{
				elapsedTime -= TimeSpan.FromSeconds(0.5);
				frameCounter = 0;
				frameRate = (float)(1000 / gameTime.ElapsedGameTime.TotalMilliseconds);
			}
		}

		public void Finish()
		{
			frameCounter++;
            totalFrames++;

			gpuWatch.Reset();
			gpuWatch.Restart();
		}
	}
}