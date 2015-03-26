//-----------------------------------------
//	ShadowMap
//-----------------------------------------

//------------------
//--- Parameters ---
float4x4 World;
float4x4 View;
float4x4 Projection;
float4x4 LightViewProj;

float2 ShadowMapPixelSize;
float ShadowMapSize;
shared float4 xLightPos;
shared float xLightPower;
shared float farClip;

bool TextureEnabled;

texture Texture;
sampler ModelTextureSampler : register(s0) = sampler_state
{
	Filter = MIN_MAG_MIP_LINEAR;
	AddressU = Wrap;
	AddressV = Wrap;
    Texture = <Texture>;
};

texture ShadowMap;
sampler ShadowMapSampler : register(s4) = sampler_state
{
	MinFilter = POINT;
	MagFilter = POINT;
	MipFilter = NONE;
	AddressU = Clamp;
	AddressV = Clamp;
    Texture = <ShadowMap>;
};

//------------------
//--- Structures ---
struct VertexShaderInput
{
	float4 Position	: POSITION;
	float2 TexCoord : TEXCOORD0;
    float4 boneIndices : BLENDINDICES0;
    float4 boneWeights : BLENDWEIGHT0;
};

struct VertexShaderOutput
{
	float4 Position : POSITION;
	float2 TexCoord : TEXCOORD0;
	float4 ShadowMapPos	: TEXCOORD1;
	float4 WorldPos : TEXCOORD2;
};

struct PixelShaderInput
{
	float4 Color : COLOR0;
	float2 TexCoord : TEXCOORD0;
	float4 ShadowMapPos	: TEXCOORD1;
	float4 WorldPos : TEXCOORD2;
};

//--------------------
//--- VertexShader ---
VertexShaderOutput VertexShaderFunction(VertexShaderInput input)
{
	VertexShaderOutput output;
	float4x4 wvp =  mul(mul(World, View), Projection);

	output.Position = mul(input.Position, wvp);
    output.WorldPos = mul(input.Position, World);

	output.ShadowMapPos = mul(output.WorldPos, LightViewProj);
    output.TexCoord = input.TexCoord;
	
	return output;
}

#define MaxBones 58
float4x4 bones[MaxBones];

VertexShaderOutput VertexShaderSkinnedAnimation(VertexShaderInput input)
{
    VertexShaderOutput output;
	float4x4 wvp =  mul(mul(World, View), Projection);

	// Blend between the weighted bone matrices.
	float4x4 skinTransform = 0;
    
	skinTransform += bones[input.boneIndices.x] * input.boneWeights.x;
	skinTransform += bones[input.boneIndices.y] * input.boneWeights.y;
	skinTransform += bones[input.boneIndices.z] * input.boneWeights.z;
	skinTransform += bones[input.boneIndices.w] * input.boneWeights.w;

	float4 position = mul(input.Position, skinTransform);

	output.Position = mul(position, wvp);
    output.WorldPos = mul(input.Position, World);

	output.ShadowMapPos = mul(output.WorldPos, LightViewProj);
    output.TexCoord = input.TexCoord;
	
	return output;
}

//-------------------
//--- PixelShader ---

// Linear filter with 4 samples
// Source by XNA Info
// http://www.xnainfo.com/content.php?content=36

float ComputeShadow4Samples(float nl, float2 texCoord, float ourdepth)
{
	/*
	float depth = ourdepth;
	//Shadow with PCF
	//coordinates for sampling
	float2 shadowCrd[9];

	shadowCrd[0] = shadowTexCoord;
	shadowCrd[1] = shadowTexCoord + float2(-ShadowMapPixelSize.x, 0.0f);
	shadowCrd[2] = shadowTexCoord + float2( ShadowMapPixelSize.x, 0.0f);
	shadowCrd[3] = shadowTexCoord + float2( 0.0f, -ShadowMapPixelSize.y);
	shadowCrd[6] = shadowTexCoord + float2( 0.0f,  ShadowMapPixelSize.y);
	shadowCrd[4] = shadowTexCoord + float2( -ShadowMapPixelSize.x, -ShadowMapPixelSize.y);
	shadowCrd[5] = shadowTexCoord + float2(  ShadowMapPixelSize.x, -ShadowMapPixelSize.y);
	shadowCrd[7] = shadowTexCoord + float2( -ShadowMapPixelSize.x,  ShadowMapPixelSize.y);
	shadowCrd[8] = shadowTexCoord + float2(  ShadowMapPixelSize.x,  ShadowMapPixelSize.y);

	float fShadowTerms[9];
	float PCF_shadow = 0.0f;

	for( int i = 0; i < 9; i++ )
	{
		float A = tex2D(ShadowMapSampler, shadowCrd[i] ).x;
		float B = (depth - 0.008f);

		// Texel is shadowed
		fShadowTerms[i] = A < B ? 0.0f : 1.0f;
		PCF_shadow += fShadowTerms[i];
	}

	PCF_shadow /=9.0f;
	*/
	// Get the current depth stored in the shadow map
	float4 samples; 
	samples.x = tex2D(ShadowMapSampler, texCoord).r < ourdepth ? 0 : 1;
	samples.y = tex2D(ShadowMapSampler, texCoord + float2(2, 0) * ShadowMapPixelSize).r < ourdepth ? 0 : 1;
	samples.z = tex2D(ShadowMapSampler, texCoord + float2(0, 2) * ShadowMapPixelSize).r < ourdepth ? 0 : 1; 
	samples.w = tex2D(ShadowMapSampler, texCoord + float2(2, 2) * ShadowMapPixelSize).r < ourdepth ? 0 : 1; 
    
	// Determine the lerp amounts           
	float2 lerps = frac(texCoord * ShadowMapSize);

	// lerp between the shadow values to calculate our light amount
	half shadow = lerp(lerp(samples.x, samples.y, lerps.x), lerp(samples.z, samples.w, lerps.x ), lerps.y); 					  
				
	return nl + ((1 - nl) * shadow);
}

float DepthBias = 0.001f;

float4 PixelShaderFunction(PixelShaderInput input) : COLOR
{
    // Color of the model
    float4 diffuse = 1;
    
    // Find the position in the shadow map for this pixel
    float2 ShadowTexCoord = input.ShadowMapPos.xy / input.ShadowMapPos.w / 2.0f + float2( 0.5, 0.5 );
    ShadowTexCoord.y = 1 - ShadowTexCoord.y;

    // Get the current depth stored in the shadow map
    float shadowdepth = tex2D(ShadowMapSampler, ShadowTexCoord).r;   
	
	return input.WorldPos; 
    
    // Calculate the current pixel depth
    // The bias is used to prevent floating point errors that occur when
    // the pixel of the occluder is being drawn
    float ourdepth = (input.ShadowMapPos.z / input.ShadowMapPos.w) - DepthBias;

	// Check to see if this pixel is in front or behind the value in the shadow map
	float nl = ComputeShadow4Samples(0.4f, ShadowTexCoord, ourdepth);  
	diffuse *= nl;
    
    return diffuse;
}

//------------------
//--- Techniques ---

technique Default
{
    pass P0
    {
        VertexShader = compile vs_2_0 VertexShaderFunction();
        PixelShader = compile ps_2_0 PixelShaderFunction();
    }
}

technique DefaultAnimated
{
    pass P0
    {
        VertexShader = compile vs_2_0 VertexShaderSkinnedAnimation();
        PixelShader = compile ps_2_0 PixelShaderFunction();
    }
}