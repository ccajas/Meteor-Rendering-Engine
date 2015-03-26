using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Text;
using System.Globalization;
using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using Microsoft.Xna.Framework.Content;
using Meteor.Resources;
using Meteor.Rendering;

namespace Meteor
{
    public class Core : DrawableComponent
    {
        /// Cameras to render with
		List <Camera> cameras; 

        Camera currentCamera;

        /// Scenes used for rendering
		List <Scene> scenes; 

        Scene currentScene;

		/// Utility classes
		RenderStats renderStats;
		QuadRenderComponent quadRenderer;
		StringBuilder debugString;

        /// Parameters to set render options
        int rtIndex = 0;
		bool ranOnce = true;
		bool debugText = true;

        public enum RtView
        {
            final,
            diffuse,
            normal,
            lights
        };

        enum RenderMethod
        {
			lpp,
            deferred,
        };
        
        /// Specifies which render target to display
        public RtView rtView;

        /// Specifies what rendering method is used
        RenderMethod renderMethod;

        /// Useful for all DrawableComponents
        SpriteFont font;
        SpriteBatch spriteBatch;
        ContentManager content;

		Texture2D nullTexture;

		float targetWidth;
		public float BufferWidth
		{
			get { return targetWidth; }
		}

		float targetHeight;
		public float BufferHeight
		{
			get { return targetHeight; }
		}

		RenderProfile currentRenderProfile;
		LightPrePassRenderer lightPrePassRenderer;
		DeferredRenderer deferredRenderer;

		RenderTarget2D debugTarget;

		/// Used to draw scenes
		SceneRenderComponent sceneRenderer;

        /// Input control
        KeyboardState currentKeyboardState = new KeyboardState();
        KeyboardState lastKeyboardState = new KeyboardState();

        public Core(IServiceProvider services, Scene scene)
            : base(services)
        {
            this.currentScene = scene;
			content = new ContentManager(services, "MeteorEngine.Content"); 
			renderStats = new RenderStats();

			ranOnce = false;
			currentRenderProfile = null;
			debugString = new StringBuilder(64, 64);

            // Setup rendering components
			cameras = new List<Camera>();
			scenes = new List<Scene>();
        }

		public override void Initialize()
		{
			base.Initialize();
		}

		public Scene AddScene(Scene scene)
		{
			scenes.Add(scene);
			currentScene = scenes[scenes.Count - 1];

			deferredRenderer.MapInputs(currentScene, currentCamera);
			lightPrePassRenderer.MapInputs(currentScene, currentCamera);

			debugTarget = new RenderTarget2D(graphicsDevice, 
				(int)targetWidth, (int)targetHeight, false, SurfaceFormat.Color, DepthFormat.Depth24, 
				4, RenderTargetUsage.PlatformContents);

			return currentScene;
		}

		public Camera AddCamera(Camera camera)
		{
			cameras.Add(camera);
			currentCamera = cameras[cameras.Count - 1];

			deferredRenderer.MapInputs(currentScene, currentCamera);
			lightPrePassRenderer.MapInputs(currentScene, currentCamera);

			return currentCamera;
		}

		public void SetViewportSize(int viewportWidth, int viewportHeight)
		{
			Viewport v = graphicsDevice.Viewport;

			v.Width = viewportWidth;
			v.Height = viewportHeight;

			graphicsDevice.Viewport = v;
		
			targetWidth = (float)graphicsDevice.Viewport.Width;
			targetHeight = (float)graphicsDevice.Viewport.Height;

			currentCamera.Initialize(targetWidth, targetHeight);
			currentRenderProfile.Initialize();

			lightPrePassRenderer.MapInputs(currentScene, currentCamera);
			deferredRenderer.MapInputs(currentScene, currentCamera);
		}

        protected override void LoadContent()
        {
            // Load debug font
            font = content.Load<SpriteFont>("Fonts/defaultFont");

            // Miscellaneous stuff
            spriteBatch = new SpriteBatch(graphicsDevice);

			targetWidth = graphicsDevice.Viewport.Width;
			targetHeight = graphicsDevice.Viewport.Height;

			// Load up all available render profiles
			deferredRenderer = new DeferredRenderer(ServiceContainer, content);
			lightPrePassRenderer = new LightPrePassRenderer(ServiceContainer, content);

			sceneRenderer = new SceneRenderComponent(graphicsDevice, content);
			quadRenderer = new QuadRenderComponent(graphicsDevice);

			nullTexture = content.Load<Texture2D>("null_color");
        }

        public override void Update(GameTime gameTime)
        {
			renderStats.Update(gameTime);

            lastKeyboardState = currentKeyboardState;
            currentKeyboardState = Keyboard.GetState();
			
			if (!ranOnce) 
			{
				currentRenderProfile = lightPrePassRenderer;
				ranOnce = true;
			}

            // Toggle between deferred and light pre-pass rendering
            if (currentKeyboardState.IsKeyDown(Keys.P) &&
                lastKeyboardState.IsKeyUp(Keys.P))
            {
                renderMethod = 1 - renderMethod;

				if (renderMethod == RenderMethod.deferred)
				{
					currentRenderProfile = deferredRenderer;
				}
				else
				{
					currentRenderProfile = lightPrePassRenderer;
				}
            }

			// Toggle debug render target display
			if (currentKeyboardState.IsKeyDown(Keys.E) &&
				lastKeyboardState.IsKeyUp(Keys.E))
			{
				rtIndex = 1 - rtIndex;
			}

			// Toggle debug text
			if (currentKeyboardState.IsKeyDown(Keys.Q) &&
				lastKeyboardState.IsKeyUp(Keys.Q))
			{
				debugText = (!debugText) ? true : false;
			}

			// Toggle debug meshes
			if (currentKeyboardState.IsKeyDown(Keys.Z) &&
				lastKeyboardState.IsKeyUp(Keys.Z))
			{
				currentScene.debug = (currentScene.debug == true) ? false : true;
			}


			if (currentCamera is FreeCamera)
			{
				(currentCamera as FreeCamera).Update(gameTime);
			}
			else if (currentCamera is DragCamera)
			{
				(currentCamera as DragCamera).Update(gameTime);
			}
			else if (currentCamera is ChaseCamera)
			{
				(currentCamera as ChaseCamera).Update(gameTime);
			}
			currentScene.Update(gameTime);
			
			base.Update(gameTime);
        }
        
        /// <summary>
        /// Main drawing function
        /// </summary>

        public override void Draw(GameTime gameTime)
        {
			RenderTarget2D output = null;

            // Draw the final output to screen
			if (currentRenderProfile != null)
			{				
				currentRenderProfile.Draw(gameTime);
				output = currentRenderProfile.Output;

				graphicsDevice.SetRenderTarget(null);
				graphicsDevice.Clear(Color.CornflowerBlue);
				
				spriteBatch.Begin(0, BlendState.Opaque, SamplerState.LinearClamp,
					DepthStencilState.None, RasterizerState.CullCounterClockwise);
				spriteBatch.Draw(output, new Rectangle(0, 0,
					(int)targetWidth, (int)targetHeight), Color.White);
				spriteBatch.End();

				/// Setup for bounding boxes
				sceneRenderer.CullModelMeshes(currentScene, currentCamera);
				sceneRenderer.DrawBoundingBoxes(currentScene, this.currentCamera);
			}

            if (rtIndex == 1)
            {
                DrawDebugData();
            }

			if (debugText == true)
			{
				DrawDebugText(renderStats.frameRate, (int)renderStats.totalFrames);
			}

			base.Draw(gameTime);
			renderStats.Finish();
        }

        /// <summary>
        /// Draw rendering stats and debug targets
        /// </summary>

        private void DrawDebugData()
        {
            int halfWidth = graphicsDevice.Viewport.Width / 6;
            int halfHeight = graphicsDevice.Viewport.Height / 6;

            //Set up Drawing Rectangle
			Rectangle rect = new Rectangle(halfWidth + 50, 10, halfWidth, halfHeight);

			spriteBatch.Begin(0, BlendState.Opaque, SamplerState.PointClamp, 
				DepthStencilState.Default, RasterizerState.CullCounterClockwise);

			for (int i = 0; i < currentRenderProfile.DebugTargets.Count; i++)
			{
				if (i == 3) rect.Height = halfWidth;

				spriteBatch.Draw(currentRenderProfile.DebugTargets[i], rect, null, Color.White);
				rect.X += halfWidth + 10;
			}

			spriteBatch.End();
        }

        /// <summary>
        /// Display text showing render settings and performance
        /// </summary>

        public void DrawDebugText(float frameRate, int totalFrames)
        {
            // Draw FPS counter
			int height = 0;

			spriteBatch.Begin();		
			spriteBatch.Draw(nullTexture, new Rectangle(0, 0, 240, font.LineSpacing * 7 + 4), 
				new Color(0, 0, 0, 120));

			spriteBatch.DrawString(font, debugString.Append("FPS: ").Concat(frameRate),
				new Vector2(4, height), Color.LawnGreen);
			debugString.Clear();
			spriteBatch.DrawString(font, debugString.Append("Frame ").Concat(totalFrames),
				new Vector2(4, font.LineSpacing + height), Color.White);
			debugString.Clear();

			Color color = (renderMethod == 0) ? Color.LawnGreen : Color.Orange;
            String rendering = (renderMethod == RenderMethod.deferred) ?
                "Using deferred rendering" : "Using light pre-pass rendering";
			debugString.Append("GPU: ").Concat((float)renderStats.GpuTime, 2);
			debugString.Append("ms");

			// Print out rendering times
			Color timeColor = (renderStats.GpuTime >= 10) ? Color.Yellow : Color.LawnGreen;
			timeColor = (renderStats.GpuTime >= 16) ? Color.Orange : timeColor;

			spriteBatch.DrawString(font, debugString,
				new Vector2(4, font.LineSpacing * 2 + height), timeColor);
			debugString.Clear();

			debugString.Concat(currentScene.totalPolys).Append(" triangles ");
			debugString.Concat(currentScene.totalLights).Append(" lights");

			spriteBatch.DrawString(font, debugString,
				new Vector2(4, font.LineSpacing * 3 + height), Color.White);
			debugString.Clear();

			spriteBatch.DrawString(font, debugString.Append("(P) ").Append(rendering),
				new Vector2(4, font.LineSpacing * 4 + height), color);
			debugString.Clear();

			spriteBatch.DrawString(font, debugString.Append("Visible meshes: ").Concat(currentScene.visibleMeshes),
				new Vector2(4, font.LineSpacing * 5 + height), Color.White);
			debugString.Clear();

			long totalMemory = GC.GetTotalMemory(false);
			spriteBatch.DrawString(font, debugString.Append("Total memory: ").Concat(totalMemory, 0),
				new Vector2(4, font.LineSpacing * 6 + height), Color.White);
			debugString.Clear();

            spriteBatch.End();
        }
    }
}