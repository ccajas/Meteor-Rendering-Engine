using System;
using System.Collections.Generic;
using System.Reflection;
using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Input;
using Microsoft.Xna.Framework.Graphics;

namespace Meteor.Resources
{
	/// <summary>
	/// Controllable camera class
	/// </summary>
	public class FreeCamera : Camera
	{
		/// <summary>
		/// Adjust smoothing to create a more fluid moving camera.
		/// Too much smoothing will cause a disorienting feel.
		/// </summary>
		float smoothing = 3.5f;
		float moveSpeed = 0.0625f;

		KeyboardState currentKeyboardState = new KeyboardState();
		GamePadState currentGamePadState = new GamePadState();

		public FreeCamera() { }

		public FreeCamera(Vector3 pos, Vector2 orientation)
		{
			position = pos;
			cameraRotation = orientation.X;
			cameraArc = orientation.Y;

			targetRotation = orientation.X;
			targetArc = orientation.Y;
		}

		/// <summary>
		/// Set the camera's matrix transformations
		/// </summary>
		protected override void UpdateMatrices()
		{
			worldMatrix =
				Matrix.CreateFromAxisAngle(Vector3.Right, MathHelper.ToRadians(cameraArc)) *
				Matrix.CreateFromAxisAngle(Vector3.Up, MathHelper.ToRadians(cameraRotation));
			view = Matrix.CreateLookAt(position, position + worldMatrix.Forward, worldMatrix.Up);

			cameraFrustum.Matrix = view * projection;
		}

		public void Update(GameTime gameTime)
		{
			float time = (float)gameTime.ElapsedGameTime.TotalMilliseconds;

			HandleControls(gameTime);
			UpdateMatrices();
		}

		/// <summary>
		/// Allows the game component to update itself.
		/// </summary>
		/// <param name="gameTime">Provides a snapshot of timing values.</param>
		private void HandleControls(GameTime gameTime)
		{
			currentKeyboardState = Keyboard.GetState();
			currentGamePadState = GamePad.GetState(PlayerIndex.One);

			float time = (float)gameTime.ElapsedGameTime.TotalMilliseconds;
			MouseState mouseState = Mouse.GetState();

			targetRotation += (float)(viewCenter.X - mouseState.X) * time / 120f;
			targetArc += (float)(viewCenter.Y - mouseState.Y) * time / 120f;

			// Reset mouse position
			if (new Vector2(mouseState.X, mouseState.Y) != viewCenter)
				Mouse.SetPosition((int)viewCenter.X, (int)viewCenter.Y);

			// Check for input to move the camera forward and back
			if (currentKeyboardState.IsKeyDown(Keys.W))
			{
				position += worldMatrix.Forward * time * moveSpeed;
			}

			if (currentKeyboardState.IsKeyDown(Keys.S))
			{
				position -= worldMatrix.Forward * time * moveSpeed;
			}

			cameraArc += currentGamePadState.ThumbSticks.Right.Y * time * 0.05f;
			cameraArc += targetArc - (cameraArc / smoothing);

			// Limit the arc movement.
			if (targetArc > 90.0f)
				targetArc = 90.0f;
			else if (targetArc < -90.0f)
				targetArc = -90.0f;

			// Check for input to move the camera sideways
			if (currentKeyboardState.IsKeyDown(Keys.D))
			{
				position += worldMatrix.Right * time * moveSpeed;
			}

			if (currentKeyboardState.IsKeyDown(Keys.A))
			{
				position += worldMatrix.Left * time * moveSpeed;
			}

			cameraRotation += currentGamePadState.ThumbSticks.Right.X * time * 0.05f;
			cameraRotation += targetRotation - (cameraRotation / smoothing);

			if (currentGamePadState.Buttons.RightStick == ButtonState.Pressed ||
				currentKeyboardState.IsKeyDown(Keys.R))
			{
				cameraArc = -30;
				cameraRotation = 0;
			}
			
		}
	}
}