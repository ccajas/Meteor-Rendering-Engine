//-----------------------------------------------------------------------------
// ReconstructDepth.fx
//
// Jorge Adriano Luna 2011
// http://jcoluna.wordpress.com
//-----------------------------------------------------------------------------

//x = radius, y = max screenspace radius

#define sampleKernelSize 8

float g_radius;
float g_intensity;
float g_scale;
float g_bias;
float2 halfPixel;

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
// Structs
//-------------------------------
struct VertexShaderInput
{
    float4 Position : POSITION0;
	float2 TexCoord : TEXCOORD0;
};

struct VertexShaderOutput
{
    float4 Position : POSITION0;
	float2 TexCoord : TEXCOORD0;
};

//-------------------------------
// Functions
//-------------------------------

VertexShaderOutput VertexShaderFunction(VertexShaderInput input)
{
    VertexShaderOutput output = (VertexShaderOutput)0;
	
	output.Position = input.Position;
	output.TexCoord = input.TexCoord + halfPixel;
	
	return output;
}

float3 getPosition(in float2 uv)
{
	float depth = tex2D(depthSampler, uv).r;

	// Convert position to world space
	float4 position = 0;
	
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
	//return tex2D(normalSampler, uv).xyz;
	return normalize(tex2D(normalSampler, uv).xyz * 2.0f - 1.0f);
}

float2 g_ScreenSize = float2(1280, 720);
float2 random_size = float2(64, 64);

float2 getRandom(in float2 uv)
{
	return normalize(tex2Dgrad(randomSampler, g_ScreenSize * uv / random_size, 0, 0).xy * 2.0f - 1.0f);
}

float doAmbientOcclusion(in float2 tcoord,in float2 uv, in float3 p, in float3 cnorm)
{
	half3 worldPos = getPosition(tcoord + uv) - p;

	const half3 vec = normalize(worldPos);
	const half distance = length(worldPos) * g_scale;
	return max(0.0, dot(cnorm, vec)) * (1.0 / (1.0 + distance));
}
  
float4 PixelShaderFunction(VertexShaderOutput IN) : COLOR0
{
	const float2 vec[8] = {
		float2(1,0),
		float2(-1,0),
        float2(0,1),
		float2(0,-1),
		float2(0.3,0),
		float2(-0.3,0),
        float2(0,0.3),
		float2(0,-0.3)
	};

	float3 p = getPosition(IN.TexCoord);
	float3 n = getNormal(IN.TexCoord);
	float2 rand = float2(0, 1);// getRandom(IN.TexCoord);

	float depthVal = tex2D(depthSampler, IN.TexCoord).r;
	if (depthVal >= 0.9999f)
		return 1;

	float ao = 0.0f;
	float rad = g_radius / p.z;

	float2 coord1, coord2;

	// SSAO Calculation //
	//[unroll(sampleKernelSize)]
	for (int j = 0; j < sampleKernelSize; ++j)
	{
		coord1 = reflect(vec[j % 4], rand) * rad;
		coord2 = float2(coord1.x * 0.707 - coord1.y * 0.707,
					  coord1.x * 0.707 + coord1.y * 0.707);
  
		ao += doAmbientOcclusion(IN.TexCoord, coord1 * 0.25, p, n);
		ao += doAmbientOcclusion(IN.TexCoord, coord2 * 0.5,  p, n);
		ao += doAmbientOcclusion(IN.TexCoord, coord1 * 0.75, p, n);
		ao += doAmbientOcclusion(IN.TexCoord, coord2, p, n);
	} 

	ao /= (float)sampleKernelSize;
	return 1 - (ao * g_intensity);
}																

technique SSAO
{
    pass Pass1
    {
        VertexShader = compile vs_3_0 VertexShaderFunction();
        PixelShader = compile ps_3_0 PixelShaderFunction();
    }
}