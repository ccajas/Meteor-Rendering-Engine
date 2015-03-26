using System;
using System.Collections.Generic;
using System.Linq;
using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Audio;
using Microsoft.Xna.Framework.Content;
using Microsoft.Xna.Framework.GamerServices;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using Microsoft.Xna.Framework.Media;
using Meteor.Resources;
using Meteor.Rendering;

namespace Meteor
{
	/// <summary>
	/// This is a game component that implements IUpdateable.
	/// </summary>
	public class MeteorDeferredRenderer : DrawableComponent
	{
		private Camera camera;
		private QuadRenderComponent quadRenderer;
		private Scene scene;
		private SceneRenderComponent sceneRenderer;

		private RenderTarget2D colorRT; //color and specular intensity
		private RenderTarget2D normalRT; //normals + specular power
		private RenderTarget2D depthRT; //depth
		private RenderTarget2D lightRT; //lighting

		private Effect clearBufferEffect;
		private Effect directionalLightEffect;

		private Effect pointLightEffect;
		private Model sphereModel; //point light volume

		private Effect finalCombineEffect;

		private SpriteBatch spriteBatch;
		private ContentManager content;

		public Camera Camera
		{
			get
			{
				return camera;
			}
		}

		public Scene Scene
		{
			get
			{
				return scene;
			}
		}

		private Vector2 halfPixel;

		public MeteorDeferredRenderer(IServiceProvider services, Scene scene, ContentManager content)
            : base(services)
		{
			this.content = content;
			this.scene = scene;
		}

		/// <summary>
		/// Allows the game component to perform any initialization it needs to before starting
		/// to run.  This is where it can query for any required services and load content.
		/// </summary>
		public override void Initialize()
		{
			// TODO: Add your initialization code here

			base.Initialize();
		}

		protected override void LoadContent()
		{
			halfPixel = new Vector2()
			{
				X = 0.5f / (float)graphicsDevice.PresentationParameters.BackBufferWidth,
				Y = 0.5f / (float)graphicsDevice.PresentationParameters.BackBufferHeight
			};

			int backbufferWidth = graphicsDevice.PresentationParameters.BackBufferWidth;
			int backbufferHeight = graphicsDevice.PresentationParameters.BackBufferHeight;

			camera = new Camera();
			//camera.CameraArc = -30;

			// Setup rendering components
			//camera = new Camera(new Vector3(-70f, 40f, 0f), new Vector2(90, 20));
			sceneRenderer = new SceneRenderComponent(graphicsDevice, content);
			quadRenderer = new QuadRenderComponent(graphicsDevice);
			camera.Initialize((float)backbufferWidth, (float)backbufferHeight);

			colorRT = new RenderTarget2D(graphicsDevice, backbufferWidth, backbufferHeight, false, SurfaceFormat.Color, DepthFormat.Depth24);
			normalRT = new RenderTarget2D(graphicsDevice, backbufferWidth, backbufferHeight, false, SurfaceFormat.Color, DepthFormat.None);
			depthRT = new RenderTarget2D(graphicsDevice, backbufferWidth, backbufferHeight, false, SurfaceFormat.Single, DepthFormat.None);
			lightRT = new RenderTarget2D(graphicsDevice, backbufferWidth, backbufferHeight, false, SurfaceFormat.Color, DepthFormat.None);

			//scene.InitializeScene();

			clearBufferEffect = content.Load<Effect>("Effects/ClearGBuffer");
			directionalLightEffect = content.Load<Effect>("Effects/DirectionalLight");
			finalCombineEffect = content.Load<Effect>("Effects/FinalCombo");
			pointLightEffect = content.Load<Effect>("Effects/PointLight");
			sphereModel = content.Load<Model>(@"Models/ball");

			spriteBatch = new SpriteBatch(graphicsDevice);
			base.LoadContent();
		}

		private void SetGBuffer()
		{
			graphicsDevice.SetRenderTargets(colorRT, normalRT, depthRT);
		}

		private void ResolveGBuffer()
		{
			graphicsDevice.SetRenderTargets(null);
		}

		private void ClearGBuffer()
		{
			clearBufferEffect.Techniques[0].Passes[0].Apply();
			quadRenderer.Render(Vector2.One * -1, Vector2.One);
		}

		private void DrawDirectionalLight(Vector3 lightDirection, Color color)
		{
			//directionalLightEffect.Parameters["colorMap"].SetValue(colorRT);
			directionalLightEffect.Parameters["normalMap"].SetValue(normalRT);
			directionalLightEffect.Parameters["depthMap"].SetValue(depthRT);

			directionalLightEffect.Parameters["lightDirection"].SetValue(lightDirection);
			directionalLightEffect.Parameters["lightColor"].SetValue(color.ToVector3());

			directionalLightEffect.Parameters["camPosition"].SetValue(camera.Position);
			directionalLightEffect.Parameters["invertViewProj"].SetValue(Matrix.Invert(camera.View * camera.Projection));
			directionalLightEffect.Parameters["inverseView"].SetValue(Matrix.Invert(camera.View));

			directionalLightEffect.Parameters["halfPixel"].SetValue(halfPixel);

			directionalLightEffect.Techniques[0].Passes[0].Apply();
			quadRenderer.Render(Vector2.One * -1, Vector2.One);
		}

		private void DrawPointLight(Vector3 lightPosition, Color color, float lightRadius, float lightIntensity)
		{
			//set the G-Buffer parameters
			//pointLightEffect.Parameters["colorMap"].SetValue(colorRT);
			pointLightEffect.Parameters["normalMap"].SetValue(normalRT);
			pointLightEffect.Parameters["depthMap"].SetValue(depthRT);

			//compute the light world matrix
			//scale according to light radius, and translate it to light position
			Matrix sphereWorldMatrix = Matrix.CreateScale(lightRadius) * Matrix.CreateTranslation(lightPosition);
			pointLightEffect.Parameters["World"].SetValue(sphereWorldMatrix);
			pointLightEffect.Parameters["View"].SetValue(camera.View);
			pointLightEffect.Parameters["Projection"].SetValue(camera.Projection);
			//light position
			pointLightEffect.Parameters["lightPosition"].SetValue(lightPosition);

			//set the color, radius and Intensity
			pointLightEffect.Parameters["Color"].SetValue(color.ToVector3());
			pointLightEffect.Parameters["lightRadius"].SetValue(lightRadius);
			pointLightEffect.Parameters["lightIntensity"].SetValue(lightIntensity);

			//parameters for specular computations
			pointLightEffect.Parameters["camPosition"].SetValue(camera.Position);
			pointLightEffect.Parameters["invertViewProj"].SetValue(Matrix.Invert(camera.View * camera.Projection));
			pointLightEffect.Parameters["inverseView"].SetValue(Matrix.Invert(camera.View));

			//size of a halfpixel, for texture coordinates alignment
			pointLightEffect.Parameters["halfPixel"].SetValue(halfPixel);
			//calculate the distance between the camera and light center
			float cameraToCenter = Vector3.Distance(camera.Position, lightPosition);
			//if we are inside the light volume, draw the sphere's inside face
			if (cameraToCenter < lightRadius)
				graphicsDevice.RasterizerState = RasterizerState.CullClockwise;
			else
				graphicsDevice.RasterizerState = RasterizerState.CullCounterClockwise;

			graphicsDevice.DepthStencilState = DepthStencilState.None;

			pointLightEffect.Techniques[0].Passes[0].Apply();
			foreach (ModelMesh mesh in sphereModel.Meshes)
			{
				foreach (ModelMeshPart meshPart in mesh.MeshParts)
				{
					graphicsDevice.Indices = meshPart.IndexBuffer;
					graphicsDevice.SetVertexBuffer(meshPart.VertexBuffer);

					graphicsDevice.DrawIndexedPrimitives(PrimitiveType.TriangleList, 0, 0, meshPart.NumVertices, meshPart.StartIndex, meshPart.PrimitiveCount);
				}
			}

			graphicsDevice.RasterizerState = RasterizerState.CullCounterClockwise;
			graphicsDevice.DepthStencilState = DepthStencilState.Default;
		}

		public override void Draw(GameTime gameTime)
		{
			SetGBuffer();
			ClearGBuffer();

			// Render the scene
			sceneRenderer.UseTechnique("GBuffer");
			sceneRenderer.Draw(scene, camera);

			ResolveGBuffer();
			DrawLights(gameTime);

			base.Draw(gameTime);
		}

		private void DrawLights(GameTime gameTime)
		{
			graphicsDevice.SetRenderTarget(lightRT);
			graphicsDevice.Clear(Color.Transparent);
			graphicsDevice.BlendState = BlendState.AlphaBlend;
			graphicsDevice.DepthStencilState = DepthStencilState.None;

			Color[] colors = new Color[10];
			colors[0] = Color.Red; colors[1] = Color.Blue;
			colors[2] = Color.IndianRed; colors[3] = Color.CornflowerBlue;
			colors[4] = Color.Gold; colors[5] = Color.Green;
			colors[6] = Color.Crimson; colors[7] = Color.SkyBlue;
			colors[8] = Color.Red; colors[9] = Color.ForestGreen;
			float angle = (float)gameTime.TotalGameTime.TotalSeconds;
			int n = 15;

			DrawDirectionalLight(new Vector3(1, -1, 1), Color.White);

			for (int i = 0; i < n; i++)
			{
				Vector3 pos = new Vector3((float)Math.Sin(i * MathHelper.TwoPi / n + angle), 0.30f, (float)Math.Cos(i * MathHelper.TwoPi / n + angle));
				DrawPointLight(pos * 40, colors[i % 10], 15, 2);
				pos = new Vector3((float)Math.Cos((i + 5) * MathHelper.TwoPi / n - angle), 0.30f, (float)Math.Sin((i + 5) * MathHelper.TwoPi / n - angle));
				DrawPointLight(pos * 20, colors[i % 10], 20, 1);
				pos = new Vector3((float)Math.Cos(i * MathHelper.TwoPi / n + angle), 0.10f, (float)Math.Sin(i * MathHelper.TwoPi / n + angle));
				DrawPointLight(pos * 75, colors[i % 10], 45, 2);
				pos = new Vector3((float)Math.Cos(i * MathHelper.TwoPi / n + angle), -0.3f, (float)Math.Sin(i * MathHelper.TwoPi / n + angle));
				DrawPointLight(pos * 20, colors[i % 10], 20, 2);
			}

			DrawPointLight(new Vector3(0, (float)Math.Sin(angle * 0.8) * 40, 0), Color.Red, 30, 5);
			DrawPointLight(new Vector3(0, 25, 0), Color.White, 30, 1);
			DrawPointLight(new Vector3(0, 0, 70), Color.Wheat, 55 + 10 * (float)Math.Sin(5 * angle), 3);

			graphicsDevice.BlendState = BlendState.Opaque;
			graphicsDevice.DepthStencilState = DepthStencilState.None;
			graphicsDevice.RasterizerState = RasterizerState.CullCounterClockwise;

			graphicsDevice.SetRenderTarget(null);

			//Combine everything
			finalCombineEffect.Parameters["diffuseMap"].SetValue(colorRT);
			finalCombineEffect.Parameters["lightMap"].SetValue(lightRT);
			finalCombineEffect.Parameters["halfPixel"].SetValue(halfPixel);

			finalCombineEffect.Techniques[0].Passes[0].Apply();
			quadRenderer.Render(Vector2.One * -1, Vector2.One);

			//Output FPS and 'credits'
			double fps = (1000 / gameTime.ElapsedGameTime.TotalMilliseconds);
			fps = Math.Round(fps, 0);
			//Game.Window.Title = "Deferred Rendering by Catalin Zima, converted to XNA4 by Roy Triesscheijn. Drawing " + (n * 4 + 3) + " lights at " + fps.ToString() + " FPS";
		}

		/// <summary>
		/// Allows the game component to update itself.
		/// </summary>
		/// <param name="gameTime">Provides a snapshot of timing values.</param>
		public override void Update(GameTime gameTime)
		{
			camera.Update();
			sceneRenderer.CullLights(scene, camera);
			sceneRenderer.CullModelMeshes(scene, camera);

			base.Update(gameTime);
		}
	}
}