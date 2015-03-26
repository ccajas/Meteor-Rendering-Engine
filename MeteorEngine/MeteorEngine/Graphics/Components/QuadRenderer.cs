
#region Using Statements
using System;
using System.Collections.Generic;
using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
#endregion

namespace Meteor.Resources
{
    public class QuadRenderComponent
    {     
		/// Rendering data
        VertexDeclaration vertexDecl = null;
        VertexPositionTexture[] verts = null;
        short[] ib = null;

		/// Graphics device passed to the object at construction
		GraphicsDevice device;

		public VertexBuffer vertexBuffer;
		public IndexBuffer indexBuffer;

        public QuadRenderComponent(GraphicsDevice device)
        {
            this.device = device;
            vertexDecl = VertexPositionTexture.VertexDeclaration;

            verts = new VertexPositionTexture[]
            {
                new VertexPositionTexture(
                    new Vector3(0,0,1),
                    new Vector2(1,1)),
                new VertexPositionTexture(
                    new Vector3(0,0,1),
                    new Vector2(0,1)),
                new VertexPositionTexture(
                    new Vector3(0,0,1),
                    new Vector2(0,0)),
                new VertexPositionTexture(
                    new Vector3(0,0,1),
                    new Vector2(1,0))
            };

            ib = new short[] { 0, 1, 2, 2, 3, 0 };

			// Set the vertex and index buffers

			vertexBuffer = new VertexBuffer(device, 
				typeof(VertexPositionTexture), 4, BufferUsage.None);
			vertexBuffer.SetData<VertexPositionTexture>(verts);

			indexBuffer = new IndexBuffer(device, IndexElementSize.SixteenBits,
				sizeof(short) * ib.Length, BufferUsage.None);
			indexBuffer.SetData<short>(ib);
        } 

		/// <summary>
		/// Draw the quad with screen space extents
		/// </summary>

        public void Render(Vector2 v1, Vector2 v2)
        {
            verts[0].Position.X = v2.X;
            verts[0].Position.Y = v1.Y;

            verts[1].Position.X = v1.X;
            verts[1].Position.Y = v1.Y;

            verts[2].Position.X = v1.X;
            verts[2].Position.Y = v2.Y;

            verts[3].Position.X = v2.X;
            verts[3].Position.Y = v2.Y;

            device.DrawUserIndexedPrimitives<VertexPositionTexture>
				(PrimitiveType.TriangleList, verts, 0, 4, ib, 0, 2);
        }

		/// <summary>
		/// Draw the quad with depth
		/// </summary>

		public void Render(Vector2 v1, Vector2 v2, float depth)
		{
			verts[0].Position.X = v2.X;
			verts[0].Position.Y = v1.Y;
			verts[0].Position.Z = depth;

			verts[1].Position.X = v1.X;
			verts[1].Position.Y = v1.Y;
			verts[1].Position.Z = depth;

			verts[2].Position.X = v1.X;
			verts[2].Position.Y = v2.Y;
			verts[2].Position.Z = depth;

			verts[3].Position.X = v2.X;
			verts[3].Position.Y = v2.Y;
			verts[3].Position.Z = depth;

			device.DrawUserIndexedPrimitives<VertexPositionTexture>
				(PrimitiveType.TriangleList, verts, 0, 4, ib, 0, 2);
		}

		public void SetVertices(Vector2 v1, Vector2 v2)
		{
			device.SetVertexBuffers(null);

			verts[0].Position.X = v2.X;
			verts[0].Position.Y = v1.Y;

			verts[1].Position.X = v1.X;
			verts[1].Position.Y = v1.Y;

			verts[2].Position.X = v1.X;
			verts[2].Position.Y = v2.Y;

			verts[3].Position.X = v2.X;
			verts[3].Position.Y = v2.Y;

			vertexBuffer.SetData<VertexPositionTexture>(verts);
		}

		/// <summary>
		/// Use instanced rendering if you need it for some reason
		/// </summary>

		public void RenderInstanced(DynamicVertexBuffer dynamicVertexBuffer, int totalInstances)
		{
			// Tell the GPU to read from both the model vertex buffer plus our instanceVertexBuffer
			device.SetVertexBuffers(
				new VertexBufferBinding(vertexBuffer, 0, 0),
				new VertexBufferBinding(dynamicVertexBuffer, 0, 1)
			);

			device.Indices = indexBuffer;

			device.DrawInstancedPrimitives(PrimitiveType.TriangleList, 0, 0, 
				4, 0, 2, totalInstances);
		}
    }
}
