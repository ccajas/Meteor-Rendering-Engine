using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.Text;
using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Content;
using Microsoft.Xna.Framework.Graphics;
using Meteor.Resources;

namespace Meteor.Rendering
{
	/// <summary>
	/// The 'Creator' abstract class
	/// </summary>
	class RendererFactory
	{
		private Dictionary<string, Type> map = new Dictionary<string, Type>();

		public RendererFactory()
		{
			Type[] rendererTypes = Assembly.GetAssembly(typeof(BaseRenderer)).GetTypes();

			foreach (Type rendererType in rendererTypes)
			{
				// if (shapeType is not derived from Shape)
				if (!typeof(BaseRenderer).IsAssignableFrom(rendererType) || 
					rendererType == typeof(BaseRenderer))
				{
					continue;
				}

				// Automatically register the shape type.
				map.Add(rendererType.Name, rendererType);
			}
		}

		public BaseRenderer Create(string shaderName, RenderProfile profile, ContentManager content)
		{
			return (BaseRenderer)Activator.CreateInstance(map[shaderName], profile, content);
		}
	}

	abstract class RenderProfile : DrawableComponent
	{
		/// List to keep all renderers in order
		protected Dictionary<string, BaseRenderer> renderTasks;
		
		/// Reference to the ContentManager to load assets
		protected ContentManager content;

		/// Track all possible starting points for this profile
		/// (Currently not yet implemented)
		protected Dictionary<string, BaseRenderer> startingPoints;
		protected Dictionary<string, BaseRenderer>.Enumerator iter;

		/// Render targets used by all the rendering tasks
		protected List <RenderTarget2D> renderTaskTargets;

		protected RenderTarget2D output;
		protected RendererFactory rendererFactory;

		public RenderTarget2D Output
		{
			get
			{
				return output;
			}
		}

		public List <RenderTarget2D> RenderTaskTargets
		{
			get
			{
				return renderTaskTargets;
			}
		}

		/// Render targets to display for debugging purposes
		protected List <RenderTarget2D> debugTargets;

		public List <RenderTarget2D> DebugTargets
		{
			get
			{
				return debugTargets;
			}
		}

		public RenderProfile(IServiceProvider service, ContentManager content)
			: base(service)
		{
			rendererFactory = new RendererFactory();

			renderTasks = new Dictionary<string, BaseRenderer>();
			startingPoints = new Dictionary<string, BaseRenderer>();
			iter = startingPoints.GetEnumerator();

			debugTargets = new List<RenderTarget2D>();
			renderTaskTargets = new List<RenderTarget2D>();

			this.Disposed += new EventHandler<EventArgs>(DisposeRenderers);
			this.content = content;
		}

		/// <summary>
		/// Initialize the SceneRenderer and call LoadContent.
		/// </summary> 

		public override void Initialize()
		{
			debugTargets.Clear();
			renderTaskTargets.Clear();

			base.Initialize();
		}

		/// <summary>
		/// Helper to add a render task and return that one after newly added
		/// Currently does nothing other than make a list
		/// </summary> 

		protected BaseRenderer AddRenderTask(BaseRenderer renderTask)
		{
			renderTasks.Add("Test", renderTask);
			return renderTasks.Last().Value;
		}

		/// <summary>
		/// Add a RenderTarget to the list of targets to use.
		/// </summary> 

		public RenderTarget2D AddRenderTarget(int width, int height, 
			SurfaceFormat surfaceFormat, DepthFormat depthFormat)
		{
			return AddRenderTarget(width, height, surfaceFormat, depthFormat, 
				RenderTargetUsage.DiscardContents);
		}

		/// <summary>
		/// Add a RenderTarget to the list of targets to use, with specified usage.
		/// </summary> 

		public RenderTarget2D AddRenderTarget(int width, int height, SurfaceFormat surfaceFormat, 
			DepthFormat depthFormat, RenderTargetUsage usage)
		{
			renderTaskTargets.Add(new RenderTarget2D(
				graphicsDevice, width, height, false, surfaceFormat, depthFormat, 1, usage));

			return renderTaskTargets.Last();
		}

		public override void Draw(GameTime gameTime)
		{
			base.Draw(gameTime);
		}

		/// <summary>
		/// Dispose of all contents of Renderers used by this render profile.
		/// </summary> 

		public void DisposeRenderers(Object sender, EventArgs e)
		{
			foreach (BaseRenderer renderTask in renderTasks.Values)
			{
				renderTask.DisposeResources();
			}

			foreach (RenderTarget2D target in renderTaskTargets)
			{
				target.Dispose();
			}

			renderTaskTargets.Clear();
		}
	}
}
