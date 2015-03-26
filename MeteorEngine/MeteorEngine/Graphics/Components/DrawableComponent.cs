using System;
using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;

namespace Meteor.Resources
{
	// This is the Meteor::DrawableComponent class, which distinguishes itself
	// from the XNA DrawableComponent, with its Meteor namespace.

	public class DrawableComponent : MeteorComponent, IDrawable
	{
		// Summary:
		//     Creates a new instance of DrawableGameComponent.
		//
		public DrawableComponent(IServiceProvider services)
			: base(services)
		{
			this.Visible = true;

			DrawOrderChanged += OnDrawOrderChanged;
			VisibleChanged += OnVisibleChanged;
		}

		// Summary:
		//     Order in which the component should be drawn, relative to other components
		//     that are in the same GameComponentCollection. Reference page contains code
		//     sample.
		public int DrawOrder { get; set; }
		//
		// Summary:
		//     The GraphicsDevice the DrawableGameComponent is associated with.
		public GraphicsDevice graphicsDevice { get; set; }

		/// <summary>Graphics device service this component is bound to.</summary>
		private IGraphicsDeviceService graphicsDeviceService;
		//
		// Summary:
		//     Indicates whether Draw should be called.
		public bool Visible { get; set; }

		// Summary:
		//     Raised when the DrawOrder property changes.
		//
		// Parameters:
		//   :
		public event EventHandler<EventArgs> DrawOrderChanged
		{
			add {}
			remove {}
		}
		//
		// Summary:
		//     Raised when the Visible property changes.
		//
		// Parameters:
		//   :
		public event EventHandler<EventArgs> VisibleChanged
		{
			add {}
			remove {}
		}

		// Summary:
		//     Releases the unmanaged resources used by the DrawableGameComponent and optionally
		//     releases the managed resources.
		//
		// Parameters:
		//   disposing:
		//     true to release both managed and unmanaged resources; false to release only
		//     unmanaged resources.
		protected override void Dispose(bool disposing)
		{
			// Unsubscribe from the graphics device service's events
			if (this.graphicsDeviceService != null)
			{
				unsubscribeFromGraphicsDeviceService();
				this.graphicsDeviceService = null;
			}
		}
		//
		// Summary:
		//     Called when the DrawableGameComponent needs to be drawn. Override this method
		//     with component-specific drawing code. Reference page contains links to related
		//     conceptual articles.
		//
		// Parameters:
		//   gameTime:
		//     Time passed since the last call to Draw.
		public virtual void Draw(GameTime gameTime)
		{

		}
		//
		// Summary:
		//     Initializes the component. Override this method to load any non-graphics
		//     resources and query for any required services.
		public override void Initialize()
		{
			// Look for the graphics device service in the game's service container
			this.graphicsDeviceService = ServiceContainer.GetService(
				typeof(IGraphicsDeviceService)) as IGraphicsDeviceService;

			// Like our XNA pendant, we absolutely require the graphics device service
			if (graphicsDeviceService == null)
				throw new InvalidOperationException("Graphics device service not found");

			// Done, now to register to the graphics device service's events
			subscribeToGraphicsDeviceService();
		}
		/// <summary>
		///   Subscribes this component to the events of the graphics device service.
		/// </summary>
		private void subscribeToGraphicsDeviceService()
		{
			// Register to the events of the graphics device service so we know when
			// the graphics device is set up, shut down or reset.
			this.graphicsDeviceService.DeviceCreated += deviceCreated;
			this.graphicsDeviceService.DeviceResetting += deviceResetting;
			this.graphicsDeviceService.DeviceReset += deviceReset;
			this.graphicsDeviceService.DeviceDisposing += deviceDisposing;

			// If a graphics device has already been created, we need to simulate the
			// DeviceCreated event that we did miss because we weren't born yet :)
			if (this.graphicsDeviceService.GraphicsDevice != null)
			{
				this.graphicsDevice = graphicsDeviceService.GraphicsDevice;
				LoadContent();
			}
		}    

		/// <summary>
		///   Unsubscribes this component from the events of the graphics device service.
		/// </summary>
		private void unsubscribeFromGraphicsDeviceService() {

			// Unsubscribe from the events again
			this.graphicsDeviceService.DeviceCreated -= new EventHandler<EventArgs>(deviceCreated);
			this.graphicsDeviceService.DeviceResetting -= new EventHandler<EventArgs>(deviceResetting);
			this.graphicsDeviceService.DeviceReset -= new EventHandler<EventArgs>(deviceReset);
			this.graphicsDeviceService.DeviceDisposing -= new EventHandler<EventArgs>(deviceDisposing);

			// If the graphics device is still active, we give the component a chance
			// to clean up its data
			if(this.graphicsDeviceService.GraphicsDevice != null) 
			{
				UnloadContent();
			}
      }
		
		
		/// <summary>Called when the graphics device is created</summary>
		/// <param name="sender">Graphics device service that created a new device</param>
		/// <param name="arguments">Not used</param>
		private void deviceCreated(object sender, EventArgs arguments)
		{
			LoadContent();
		}

		/// <summary>Called before the graphics device is being reset</summary>
		/// <param name="sender">Graphics device service that is resetting its device</param>
		/// <param name="arguments">Not used</param>
		private void deviceResetting(object sender, EventArgs arguments)
		{

		}

		/// <summary>Called after the graphics device has been reset</summary>
		/// <param name="sender">Graphics device service that has just reset its device</param>
		/// <param name="arguments">Not used</param>
		private void deviceReset(object sender, EventArgs arguments)
		{

		}

		/// <summary>Called before the graphics device is being disposed</summary>
		/// <param name="sender">Graphics device service that's disposing the device</param>
		/// <param name="arguments">Not used</param>
		private void deviceDisposing(object sender, EventArgs arguments)
		{
			UnloadContent();
		}
		//
		// Summary:
		//     Called when graphics resources need to be loaded. Override this method to
		//     load any component-specific graphics resources.
		protected virtual void LoadContent()
		{

		}
		//
		// Summary:
		//     Called when the DrawOrder property changes. Raises the DrawOrderChanged event.
		//
		// Parameters:
		//   sender:
		//     The DrawableGameComponent.
		//
		//   args:
		//     Arguments to the DrawOrderChanged event.
		protected virtual void OnDrawOrderChanged(object sender, EventArgs args)
		{

		}
		//
		// Summary:
		//     Called when the Visible property changes. Raises the VisibleChanged event.
		//
		// Parameters:
		//   sender:
		//     The DrawableGameComponent.
		//
		//   args:
		//     Arguments to the VisibleChanged event.
		protected virtual void OnVisibleChanged(object sender, EventArgs args)
		{

		}
		//
		// Summary:
		//     Called when graphics resources need to be unloaded. Override this method
		//     to unload any component-specific graphics resources.
		protected virtual void UnloadContent()
		{

		}
	}
}
