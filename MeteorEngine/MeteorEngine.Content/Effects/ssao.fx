
//x = radius, y = max screenspace radius

#define sampleKernelSize 3

float g_radius;
float g_intensity;
float g_scale;
float g_bias;
float2 halfPixel;
float farClip;

float4x4 invertViewProj;
float4x4 invertProjection;
float4x4 View;
float4x4 Projection;

//-----------------------------------------
// Textures
//-----------------------------------------

texture NormalBuffer;
sampler2D normalSampler : register(s1) = sampler_state
{
	Texture = <NormalBuffer>;
	MipFilter = NONE;
	MagFilter = LINEAR;
	MinFilter = LINEAR;
	AddressU = Clamp;
	AddressV = Clamp;
};

texture DepthBuffer;
sampler2D depthSampler : register(s4) = sampler_state
{
	Texture = <DepthBuffer>;
	MipFilter = NONE;
	MagFilter = POINT;
	MinFilter = POINT;
	AddressU = Clamp;
	AddressV = Clamp;
};

texture RandomMap;
sampler2D randomSampler = sampler_state
{
	Texture = <RandomMap>;
	MipFilter = NONE;
	MagFilter = POINT;
	MinFilter = POINT;
	AddressU = Wrap;
	AddressV = Wrap;
};

//-------------------------------
// Functions
//-------------------------------

#include "Includes/screenQuad.fxh"

float3 getPosition(in float2 uv)
{
	float depth = tex2D(depthSampler, uv).r;

	// Convert position to world space
	float4 position = 0;//tex2D(positionSampler, uv);
	
	position.xy = uv.x * 2.0f - 1.0f;
	position.y = -(uv.y * 2.0f - 1.0f);
	position.z = depth;
	position.w = 1.0f;

	position = mul(position, invertViewProj);
	position /= position.w;
	
	//return position;
	return mul(position, View);
}

float3 getNormal(in float2 uv)
{
	return normalize(tex2D(normalSampler, uv).xyz * 2.0f - 1.0f);
}

float2 g_ScreenSize = float2(1280, 720);
float2 random_size = float2(64, 64);

float2 getRandom(in float2 uv)
{
	return normalize(tex2D(randomSampler, g_ScreenSize * uv / random_size).xy * 2.0f - 1.0f);
}

float doAmbientOcclusion(in float2 tcoord,in float2 uv, in float3 p, in float3 cnorm)
{
	float3 worldPos = getPosition(tcoord + uv) - p;

	const float3 vec = normalize(worldPos);
	const float distance = length(worldPos) * g_scale;
	return max(0.0, dot(cnorm, vec) - g_bias) * (1.0 / (1.0 + distance));
}
  
float4 PixelShaderFunction(VertexShaderOutput IN) : COLOR0
{
	//return float4(tex2D(randomSampler, IN.TexCoord).rgb, 1);

	const float2 vec[4] = {
		float2(1,0),
		float2(-1,0),
        float2(0,1),
		float2(0,-1)
	};

	float3 p = getPosition(IN.TexCoord);
	float3 n = getNormal(IN.TexCoord);
	float2 rand = getRandom(IN.TexCoord);

	float depthVal = tex2D(depthSampler, IN.TexCoord).r;
	if (depthVal >= 0.99999f)
		return 1;

	float ao = 0.0f;
	float rad = g_radius / p.z;

	float2 coord1, coord2;

	// SSAO Calculation //
	for (int j = 0; j < sampleKernelSize; ++j)
	{
		coord1 = reflect(vec[j], rand) * rad;
		coord2 = float2(coord1.x * 0.707 - coord1.y * 0.707,
					  coord1.x * 0.707 + coord1.y * 0.707);
  
		ao += doAmbientOcclusion(IN.TexCoord, coord1 * 0.25, p, n);
		ao += doAmbientOcclusion(IN.TexCoord, coord2 * 0.5,  p, n);
		ao += doAmbientOcclusion(IN.TexCoord, coord1 * 0.75, p, n);
		ao += doAmbientOcclusion(IN.TexCoord, coord2, p, n);
	} 

	ao /= (float)sampleKernelSize;
	float attenuate = 1 - pow(depthVal, 10);
	return 1 - (ao * attenuate * g_intensity);
}																

technique SSAO
{
    pass Pass1
    {
        VertexShader = compile vs_3_0 VertexShaderFunction();
        PixelShader = compile ps_3_0 PixelShaderFunction();
    }
}