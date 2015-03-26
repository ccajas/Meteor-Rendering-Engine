//-----------------------------------------
//	ShadowMap
//-----------------------------------------

//------------------
//--- Parameters ---
float4x4 World;
float4x4 View;
float4x4 Projection;
float4x4 LightView;
float4x4 LightProjection;

float4x4 InverseViewProjection;
shared float4 xLightPos;
shared float xLightPower;
shared float farClip;

float3 LightPosition;

Texture ShadowMap;
sampler ShadowMapSampler = sampler_state
{
    Texture = <ShadowMap>;
    Filter = MIN_MAG_MIP_POINT;
    AddressU = Clamp;
    AddressV = Clamp;
};

Texture DepthMap;
sampler DepthMapSampler = sampler_state
{
    Texture = <DepthMap>;
    Filter = MIN_MAG_MIP_POINT;
    AddressU = Clamp;
    AddressV = Clamp;
};

bool TextureEnabled;
texture Texture;

sampler ModelTextureSampler = sampler_state
{
    Texture = <Texture>;
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Wrap;
    AddressV = Wrap;
};

//------------------
//--- Structures ---
struct VertexShaderInput
{
	float4 Position	: POSITION;
	float2 TexCoords : TEXCOORD0;
	float3 Normal : NORMAL;
    float4 boneIndices : BLENDINDICES0;
    float4 boneWeights : BLENDWEIGHT0;
};

struct VertexShaderOutput
{
	float4 position	: POSITION;
	float4 ShadowMapPos	: TEXCOORD0;
	float RealDistance : TEXCOORD1;
	float2 TexCoords : TEXCOORD2;
	float3 Normal : TEXCOORD3;
	float4 ScreenPosition : TEXCOORD4;
};

struct PixelShaderInput
{
	float4 Color : COLOR0;
	float4 ShadowMapPos	: TEXCOORD0;
	float  RealDistance : TEXCOORD1;
	float2 TexCoords : TEXCOORD2;
	float3 Normal : TEXCOORD3;
	float4 ScreenPosition : TEXCOORD4;
};

//--------------------
//--- VertexShader ---
VertexShaderOutput VertexShaderFunction(VertexShaderInput input)
{
	VertexShaderOutput output;
	output.position = mul(mul(mul(input.Position, World), View), Projection);
	output.ShadowMapPos = mul(mul(mul(input.Position, World), LightView), LightProjection);

	//Pass to ScreenPosition
	output.ScreenPosition = output.position;
	output.RealDistance = output.ShadowMapPos.z / farClip;
    output.Normal = normalize(mul(input.Normal, (float3x3)World));
 
    output.TexCoords = input.TexCoords;
	
	return output;
}

#define MaxBones 58
float4x4 bones[MaxBones];

VertexShaderOutput VertexShaderSkinnedAnimation(VertexShaderInput input)
{
    VertexShaderOutput output;

	// Blend between the weighted bone matrices.
	float4x4 skinTransform = 0;
    
	skinTransform += bones[input.boneIndices.x] * input.boneWeights.x;
	skinTransform += bones[input.boneIndices.y] * input.boneWeights.y;
	skinTransform += bones[input.boneIndices.z] * input.boneWeights.z;
	skinTransform += bones[input.boneIndices.w] * input.boneWeights.w;

	input.Normal = mul(input.Normal, skinTransform);
	float4 worldPosition = mul(input.Position, skinTransform);

	output.position = mul(mul(mul(worldPosition, World), View), Projection);
	output.ShadowMapPos = mul(mul(mul(input.Position, World), LightView), LightProjection);

	//Pass to ScreenPosition
	output.ScreenPosition = output.position;
	output.RealDistance = output.ShadowMapPos.z / farClip;
    output.Normal = normalize(mul(input.Normal, (float3x3)World));
 
    output.TexCoords = input.TexCoords;
	
	return output;
}

//-------------------
//--- PixelShader ---
float DotProduct(float4 LightPos, float3 Pos3D, float3 Normal)
{
    float3 LightDir = normalize(LightPos - Pos3D);
    return dot(LightDir, Normal);
}

float linstep(float min, float max, float v)  
{  
	return clamp((v - min) / (max - min), 0, 1);  
}  

float ReduceLightBleeding(float pMax, float Amount)  
{  
	// Remove the [0, Amount] tail and linearly rescale (Amount, 1].  
	return linstep(Amount, 1, pMax);  
} 

float4 PixelShaderFunction(PixelShaderInput input) : COLOR
{
	input.ScreenPosition.xy /= input.ScreenPosition.w;
    float2 ProjectedTexCoords = 0.5f * (float2(input.ScreenPosition.x, -input.ScreenPosition.y) +
		1) - float2(1.0f / 512.0f, 1.0f / 512.0f);
    
    //ProjectedTexCoords[0] = input.ShadowMapPos.x / input.ShadowMapPos.w / 2.0f + 0.5f;
    //ProjectedTexCoords[1] = -input.ShadowMapPos.y / input.ShadowMapPos.w / 2.0f + 0.5f;

	float Depth = tex2D(DepthMapSampler, ProjectedTexCoords).x;

	// Make position in homogenous space using current ScreenSpace coordinates and 
	// the Depth from the GBuffer

	float4 position = 1.0f;
	position.xy = input.ScreenPosition.xy;
	position.z = Depth;

	// Transform position from homogenous space to World Space
	position = mul(position, InverseViewProjection);
	position /= position.w;

	// Calculate homogenous position with respect to light
	float4 lightScreenPos = mul(position, mul(LightView, LightProjection));

	lightScreenPos /= lightScreenPos.w;

	//Calculate Projected UV from Light POV
	float2 lightUV = 0.5f * (float2(lightScreenPos.x, -lightScreenPos.y) + 1);

	//Load the Projected Depth from the Shadow Map, do manual linear filtering
	float lZ = tex2D(ShadowMapSampler, lightUV);

	// Asymmetric Workaround...
	float shadowFactor = 1;
	float len = max(0.01f, length(LightPosition - position)) / farClip;

	//Calculate the Shadow Factor
	shadowFactor = (lZ * exp(-(farClip * 0.5f) * (len - 0.00002f))) + 0.2f;

	float mask = tex2D(ModelTextureSampler, input.TexCoords).a;
	return shadowFactor;
}

//------------------
//--- Techniques ---

technique Default
{
    pass P0
    {
		ZEnable = true;
        VertexShader = compile vs_2_0 VertexShaderFunction();
        PixelShader = compile ps_2_0 PixelShaderFunction();
    }
}

technique DefaultAnimated
{
    pass P0
    {
		ZEnable = true;
        VertexShader = compile vs_2_0 VertexShaderSkinnedAnimation();
        PixelShader = compile ps_2_0 PixelShaderFunction();
    }
}