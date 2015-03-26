using System;
using System.Collections.Generic;
using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Content;

namespace Meteor.Resources
{
	public class SkyBox
	{
		private Model skyboxMesh;
		public Vector3 myPosition;
		public Quaternion myRotation;
		public Vector3 myScale;

		public TextureCube environ;

		Effect shader;

		string modelAsset;
		string shaderAsset;
		string textureAsset;

		ContentManager content;

		public SkyBox(ContentManager content, string modelAsset, string shaderAsset, string textureAsset)
		{
			this.content = content;

			this.modelAsset = modelAsset;
			this.shaderAsset = shaderAsset;
			this.textureAsset = textureAsset;

			myPosition = new Vector3(0, 0, 0);
			myRotation = new Quaternion(0, 0, 0, 1);
			myScale = new Vector3(55, 55, 55);

			LoadContent(modelAsset, shaderAsset, textureAsset);
		}

		private void LoadContent(string modelAsset, string shaderAsset, string textureAsset)
		{
			skyboxMesh = content.Load<Model>(modelAsset);
			shader = content.Load<Effect>(shaderAsset);
			environ = content.Load<TextureCube>(textureAsset);
		}

		public void Draw(Camera camera)
		{
			Matrix World = Matrix.CreateScale(myScale) *
				Matrix.CreateFromQuaternion(myRotation) *
				Matrix.CreateTranslation(camera.Position);

			shader.Parameters["World"].SetValue(World);
			shader.Parameters["View"].SetValue(camera.View);
			shader.Parameters["Projection"].SetValue(camera.Projection);
			shader.Parameters["surfaceTexture"].SetValue(environ);

			shader.Parameters["EyePosition"].SetValue(camera.Position);

			foreach (ModelMesh mesh in skyboxMesh.Meshes)
			{
				for (int prt = 0; prt < mesh.MeshParts.Count; prt++)
				{
					mesh.MeshParts[prt].Effect = shader;

					for (int pass = 0; pass < shader.CurrentTechnique.Passes.Count; pass++)
					{
						mesh.Draw();
					}
				}
			}
			// Finish drawing
		}
	}
}