//-----------------------------------------
// TerrainGBuffer
//-----------------------------------------

#include "Includes/terrainConstants.fxh"
#include "Includes/vertexTerrain.fxh"

//--- PixelShaders ---//

struct PixelShaderOutput1
{
    float4 Normal : COLOR0;
    float4 Depth : COLOR1;
    float4 Color : COLOR2;
};

struct PixelShaderOutput2
{
    float4 Normal : COLOR0;
    float4 Depth : COLOR1;
};

float4 TriplanarMapping(VT_Output input, float scale = 1)
{
	float tighten = 0.434679f; 

	float mXY = saturate(abs(input.Normal.z) - tighten);
	float mXZ = saturate(abs(input.Normal.y) - tighten);
	float mYZ = saturate(abs(input.Normal.x) - tighten);

	float total = mXY + mXZ + mYZ;
	mXY /= total;
	mXZ /= total;
	mYZ /= total;
	
	float4 cXY = tex2D(baseSteepSampler, input.NewPosition.xy / textureScale * scale);
	float4 cXZ = tex2D(baseSampler, input.NewPosition.xz / textureScale * scale);
	float4 cYZ = tex2D(baseSteepSampler, input.NewPosition.zy / textureScale * scale);

	float4 diffuse = cXY * mXY + cXZ * mXZ + cYZ * mYZ;
	return diffuse;
}

float3 TriplanarNormalMapping(VT_Output input, float scale = 1)
{
	float tighten = 0.434679f; 

	float mXY = saturate(abs(input.Normal.z) - tighten);
	float mXZ = saturate(abs(input.Normal.y) - tighten);
	float mYZ = saturate(abs(input.Normal.x) - tighten);

	float total = mXY + mXZ + mYZ;
	mXY /= total;
	mXZ /= total;
	mYZ /= total;
	
	float3 cXY = tex2D(steepNormalMapSampler, input.NewPosition.xy / textureScale * scale);
	float3 cXZ = float3(0, 0, 1);
	float3 cYZ = tex2D(steepNormalMapSampler, input.NewPosition.zy / textureScale * scale);

	cXY = 2.0f * cXY - 1.0f;
	cYZ = 2.0f * cYZ - 1.0f;

	float3 normal = cXY * mXY + cXZ * mXZ + cYZ * mYZ;
	normal.xy *= bumpIntensity;
	return normal;
}

PixelShaderOutput1 PixelTerrainGBuffer(VT_Output input)
{
    PixelShaderOutput1 output = (PixelShaderOutput1)1;

	// Determine diffuse texture color
	float4 color = TriplanarMapping(input, 2); // close
	float4 blendedColor = TriplanarMapping(input, 0.1f); // far
	float4 blendedColor2 = TriplanarMapping(input, 0.12f);

	float blendDepth = pow(input.Depth.x / input.Depth.y, 2 * textureScale);

	// Calculate the projected texture coordinates.
    float2 projectedTexCoord;
	projectedTexCoord.x =  input.ViewPosition.x / input.ViewPosition.w / 2.0f + 0.5f;
    projectedTexCoord.y = -input.ViewPosition.y / input.ViewPosition.w / 2.0f + 0.5f;

	float4 projectionColor = 0;

    if ((saturate(projectedTexCoord.x) == projectedTexCoord.x) && 
		(saturate(projectedTexCoord.y) == projectedTexCoord.y))
    {
        projectionColor = 0.5f;// projectionTexture.Sample(SampleType, projectTexCoord);
    }

	// Blend with scaled texture
	//blendedColor = lerp(blendedColor, blendedColor2, 0.5f);
	output.Color = lerp(color, blendedColor, blendDepth);
	//output.Color += projectionColor;

	// Sample normal map color
	float3 normal = TriplanarNormalMapping(input, 2);
	float3 blendedNormal = TriplanarNormalMapping(input, 0.3f);
	float3 blendedNormal2 = TriplanarNormalMapping(input, 0.22f);

	blendedNormal = lerp(blendedNormal, blendedNormal2, 0.5f);
	normal = lerp(normal, blendedNormal, blendDepth);

	// Output the normal, in [0,1] space
    // Get normal into world space

    float3 normalFromMap = mul(normal, input.TangentToWorld);  
	normalFromMap = normalize(normalFromMap);
	output.Normal.rgb = 0.5f * (normalFromMap + 1.0f);

	// Assign some specular power if needed
    output.Normal.a = specIntensity;

	// Output Depth
	output.Depth = input.Depth.x / input.Depth.y; 
    return output;
}

PixelShaderOutput2 PixelTerrainSmallGBuffer(VT_Output input)
{
    PixelShaderOutput2 output = (PixelShaderOutput2)1;

    // Output the normal, in [0,1] space
    float3 normalFromMap = float3(0.5, 0.5, 1);//tex2D(normalMapSampler, input.TexCoord);

    normalFromMap = mul(normalFromMap, input.Normal);	
    normalFromMap = normalize(mul(normalFromMap, View));
    output.Normal.rgb = 0.5f * (normalFromMap + 1.0f);

	// Terrain doesn't need any specular component
    output.Normal.a = 0;

	// Output Depth
	output.Depth = input.Depth.x / input.Depth.y; 
    return output;
}

float4 PixelTerrainDiffuse(VT_Output input) : COLOR0
{
	float3 h = input.NewPosition.y;
	float4 color = TriplanarMapping(input, 4);
	float4 blendedColor = TriplanarMapping(input, 0.3f);

	float depth = pow(abs(input.Depth.x / input.Depth.y), 50);

	// Blend with scaled texture
	color = lerp(color, blendedColor, depth);
	color.a = 1;
	 
	return color;//float4(0, ClipLevel % 2, 1, 1);
}

PixelShaderOutput1 PixelTerrainDebug(VT_Output input)
{
    PixelShaderOutput1 output = (PixelShaderOutput1)1;

	float3 color = float3(1, 1, 1);
	output.Color.rgb = color;
	output.Color.a = 1;

	output.Normal.rgb = float3(0.5, 0.5, 1);
	output.Normal.a = 0;

	// Output Depth and Specular
	output.Depth = input.Depth.x / input.Depth.y; 

    return output;
}

/// The following four techniques draw a variation of the GBuffer, 
/// either with two render targets (light pre-pass) or three render 
/// targets (deferred) simultaneously.

technique GBufferTerrain
{
    pass Pass1
    {
		CullMode = CCW;
		ZENABLE = True;

        VertexShader = compile vs_3_0 VertexShaderTerrain();
        PixelShader = compile ps_3_0 PixelTerrainGBuffer();
    }
}

technique SmallGBufferTerrain
{
    pass Pass1
    {
		CullMode = CCW;
		ZENABLE = True;

        VertexShader = compile vs_3_0 VertexShaderTerrain();
        PixelShader = compile ps_3_0 PixelTerrainSmallGBuffer();
    }
}

/// Separately render the diffuse/albedo component to combine, for light pre-pass.

technique DiffuseRenderTerrain
{
    pass Pass1
    {
		CullMode = CCW;
		ZENABLE = True;

        VertexShader = compile vs_3_0 VertexShaderTerrain();
        PixelShader = compile ps_3_0 PixelTerrainDiffuse();
    }
}

/// Simple rendering mode for debug views

technique DebugTerrain
{
    pass Pass1
    {
		CullMode = CCW;
		ZENABLE = True;

        VertexShader = compile vs_2_0 VertexShaderTerrain(0.05f);
        PixelShader = compile ps_2_0 PixelTerrainDebug();
    }
}
