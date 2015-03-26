
using System;
using System.Collections.Generic;
using System.Text;
using Microsoft.Xna.Framework.Content.Pipeline;
using Microsoft.Xna.Framework.Content.Pipeline.Processors;
using Microsoft.Xna.Framework.Content.Pipeline.Graphics;
using Microsoft.Xna.Framework.Graphics.PackedVector;
using Microsoft.Xna.Framework;
using System.ComponentModel;

namespace DeferredRenderingPipeline
{
	/// <summary>
	/// The NormalMapTextureProcessor takes in an encoded normal map, and outputs
	/// a texture in the NormalizedByte4 format.  Every pixel in the source texture
	/// is remapped so that values ranging from 0 to 1 will range from -1 to 1.
	/// </summary>
	[ContentProcessor]
	[DesignTimeVisible(false)]
	class DeferredTextureProcessor : ContentProcessor<TextureContent, TextureContent>
	{
		/// <summary>
		/// Process converts the encoded normals to the NormalizedByte4 format and 
		/// generates mipmaps.
		/// </summary>
		/// <param name="input"></param>
		/// <param name="context"></param>
		/// <returns></returns>
		public override TextureContent Process(TextureContent input,
			ContentProcessorContext context)
		{
			// convert to vector4 format, so that we know what kind of data we're 
			// working with.
			input.ConvertBitmapType(typeof(PixelBitmapContent<Vector4>));

			Texture2DContent output = new Texture2DContent();

			// expand the encoded normals; values ranging from 0 to 1 should be
			// expanded to range to -1 to 1.
			// NOTE: in almost all cases, the input normalmap will be a
			// Texture2DContent, and will only have one face.  just to be safe,
			// we'll do the conversion for every face in the texture.

			int mmIndex = 0;

			foreach (MipmapChain mipmapChain in input.Faces)
			{
				int bmpIndex = 0;

				foreach (PixelBitmapContent<Vector4> bitmap in mipmapChain)
				{
					// Copy original bitmap to the new texture
					output.Faces[mmIndex].Add(bitmap);

					PixelBitmapContent<NormalizedByte4> normalizedBitmap =
						new PixelBitmapContent<NormalizedByte4>(bitmap.Width, bitmap.Height);

					for (int x = 0; x < bitmap.Width; x++)
					{
						for (int y = 0; y < bitmap.Height; y++)
						{
							Vector4 encoded = 2 * bitmap.GetPixel(x, y) - Vector4.One;
							normalizedBitmap.SetPixel(x, y, new NormalizedByte4(encoded));
						}
					}
					// now that the conversion to -1 to 1 ranges is finished, convert to the 
					// runtime-ready format NormalizedByte4.
					output.Faces[mmIndex][bmpIndex++] = normalizedBitmap;
				}
				mmIndex++;
			}
			// Overwriting mipmaps isn't needed here.
			output.GenerateMipmaps(false);
			return output;
		}
	}
}
