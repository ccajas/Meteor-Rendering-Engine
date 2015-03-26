using System;
using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;

namespace Meteor.Resources
{
	public class MeteorComponent : IGameComponent, IUpdateable, IDisposable
	{
		// Summary:
		//     Initializes a new instance of this class.
		//
		public MeteorComponent(IServiceProvider services)
		{
			this.services = services;
			this.Enabled = true;

			EnabledChanged += OnEnabledChanged;
			UpdateOrderChanged += OnUpdateOrderChanged;
			Disposed += OnUpdateOrderChanged;
		}

		private IServiceProvider services;

		/// <summary>Service container the component was constructed for</summary>
		public IServiceProvider ServiceContainer
		{
			get { return this.services; }
		}

		// Summary:
		//     Indicates whether GameComponent.Update should be called when Game.Update
		//     is called.
		public bool Enabled { get; set; }
		//
		// Summary:
		//     Indicates the order in which the GameComponent should be updated relative
		//     to other GameComponent instances. Lower values are updated first.
		public int UpdateOrder { get; set; }

		// Summary:
		//     Raised when the GameComponent is disposed.
		//
		// Parameters:
		//   :
		public event EventHandler<EventArgs> Disposed;
		//
		// Summary:
		//     Raised when the Enabled property changes.
		//
		// Parameters:
		//   :
		public event EventHandler<EventArgs> EnabledChanged
		{
			add {}
			remove {}
		}
		//
		// Summary:
		//     Raised when the UpdateOrder property changes.
		//
		// Parameters:
		//   :
		public event EventHandler<EventArgs> UpdateOrderChanged
		{
			add {}
			remove {}
		}

		// Summary:
		//     Immediately releases the unmanaged resources used by this object.
		public void Dispose()
		{
			EventArgs e = null;
			this.Disposed(this, e);
		}
		//
		// Summary:
		//     Releases the unmanaged resources used by the GameComponent and optionally
		//     releases the managed resources.
		//
		// Parameters:
		//   disposing:
		//     true to release both managed and unmanaged resources; false to release only
		//     unmanaged resources.
		protected virtual void Dispose(bool disposing)
		{

		}
		//
		// Summary:
		//     Reference page contains code sample.
		public virtual void Initialize()
		{

		}
		//
		// Summary:
		//     Called when the Enabled property changes. Raises the EnabledChanged event.
		//
		// Parameters:
		//   sender:
		//     The GameComponent.
		//
		//   args:
		//     Arguments to the EnabledChanged event.
		protected virtual void OnEnabledChanged(object sender, EventArgs args)
		{

		}
		//
		// Summary:
		//     Called when the UpdateOrder property changes. Raises the UpdateOrderChanged
		//     event.
		//
		// Parameters:
		//   sender:
		//     The GameComponent.
		//
		//   args:
		//     Arguments to the UpdateOrderChanged event.
		protected virtual void OnUpdateOrderChanged(object sender, EventArgs args)
		{

		}
		//
		// Summary:
		//     Called when the GameComponent needs to be updated. Override this method with
		//     component-specific update code.
		//
		// Parameters:
		//   gameTime:
		//     Time elapsed since the last call to Update
		public virtual void Update(GameTime gameTime)
		{

		}
	}
}
