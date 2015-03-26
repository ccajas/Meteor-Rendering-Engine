//-----------------------------------------
//	DepthMap
//-----------------------------------------

//--- Parameters ---

float4x4 World;
float4x4 LightViewProj;
float nearClip;

texture Texture;
sampler diffuseSampler : register(s0) = sampler_state
{
	Filter = MIN_MAG_MIP_LINEAR;
	AddressU = Wrap;
	AddressV = Wrap;
    Texture = <Texture>;
};

//--- Structures ---

struct VertexShaderInput
{
    float4 Position : POSITION;
    float2 TexCoord : TEXCOORD0;
    float4 boneIndices : BLENDINDICES0;
    float4 boneWeights : BLENDWEIGHT0;
};

struct VertexShaderOutput
{
	float4 position : POSITION;
	float2 texCoord : TEXCOORD0;
	float depth : TEXCOORD1;
};

struct InstanceInput
{
	float4 vWorld1 : TEXCOORD1;
	float4 vWorld2 : TEXCOORD2;
	float4 vWorld3 : TEXCOORD3;
	float4 vWorld4 : TEXCOORD4;
};

//--- VertexShader ---

VertexShaderOutput DepthMapVS(VertexShaderInput input, InstanceInput instance)
{
	VertexShaderOutput output;
	float4x4 WorldInstance = 
		float4x4(instance.vWorld1, instance.vWorld2, instance.vWorld3, instance.vWorld4);

	float4 position = mul(input.Position, WorldInstance);
	
	output.position = mul(position, mul(World, LightViewProj));
	output.depth = output.position.z;

	//pass the texture coordinates further
    output.texCoord = input.TexCoord;
	
	return output;
}

#define MaxBones 60
float4x4 bones[MaxBones];

VertexShaderOutput DepthMapSkinnedAnimation(VertexShaderInput input, InstanceInput instance)
{
    VertexShaderOutput output;

	float4x4 WorldInstance = 
		float4x4(instance.vWorld1, instance.vWorld2, instance.vWorld3, instance.vWorld4);

	// Blend between the weighted bone matrices.
	float4x4 skinTransform = 0;
    
	skinTransform += bones[input.boneIndices.x] * input.boneWeights.x;
	skinTransform += bones[input.boneIndices.y] * input.boneWeights.y;
	skinTransform += bones[input.boneIndices.z] * input.boneWeights.z;
	skinTransform += bones[input.boneIndices.w] * input.boneWeights.w;

	float4 position = mul(input.Position, skinTransform);
	position = mul(position, WorldInstance);

	output.position = mul(position, mul(World, LightViewProj));
	output.depth = output.position.z;

	//pass the texture coordinates further
    output.texCoord = input.TexCoord;
	
	return output;
}

//--- PixelShader ---

float4 DepthMapPS (VertexShaderOutput IN) : COLOR0
{
	float mask = tex2D(diffuseSampler, IN.texCoord).a;
	clip (mask - 0.01);
	
    return IN.depth;
}

//--- Techniques ---

technique Default
{
    pass P0
    {
		ZEnable = true;
		CullMode = CCW;
        VertexShader = compile vs_3_0 DepthMapVS();
        PixelShader = compile ps_3_0 DepthMapPS();
    }
}

technique DefaultAnimated
{
    pass P0
    {
		ZEnable = true;
		CullMode = CCW;
        VertexShader = compile vs_3_0 DepthMapSkinnedAnimation();
        PixelShader = compile ps_3_0 DepthMapPS();
    }
}