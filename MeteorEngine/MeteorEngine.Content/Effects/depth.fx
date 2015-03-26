//-----------------------------------------
//	DepthMap
//-----------------------------------------

//--- Parameters ---

float4x4 World;
float4x4 LightViewProj;

float3 viewPosition;
float nearClip = 4;
float farClip = 4000;

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
	float2 depth : TEXCOORD1;
};

//--- VertexShader ---

VertexShaderOutput DepthMapVS(VertexShaderInput input)
{
	VertexShaderOutput output;

	float4 position = input.Position;
	
	output.position = mul(position, mul(World, LightViewProj));

	//pass the texture coordinates further
    output.texCoord = input.TexCoord;
	output.depth = output.position.zw;
	
	return output;
}

VertexShaderOutput DepthMapLinearVS(VertexShaderInput input)
{
	VertexShaderOutput output;

	float4 position = input.Position;
	
	output.position = mul(position, mul(World, LightViewProj));

	//pass the texture coordinates further
    output.texCoord = input.TexCoord;

	float3 worldPosition = mul(position, World) - viewPosition;
	output.depth = dot(viewPosition, worldPosition);
	output.depth = (output.depth - nearClip) / (farClip - nearClip);
	
	return output;
}

#define MaxBones 58
float4x4 bones[MaxBones];

VertexShaderOutput DepthMapSkinnedAnimation(VertexShaderInput input)
{
    VertexShaderOutput output;

	// Blend between the weighted bone matrices.
	float4x4 skinTransform = 0;
    
	skinTransform += bones[input.boneIndices.x] * input.boneWeights.x;
	skinTransform += bones[input.boneIndices.y] * input.boneWeights.y;
	skinTransform += bones[input.boneIndices.z] * input.boneWeights.z;
	skinTransform += bones[input.boneIndices.w] * input.boneWeights.w;

	float4 position = mul(input.Position, skinTransform);

	output.position = mul(position, mul(World, LightViewProj));
	output.depth = output.position.zw;

	//pass the texture coordinates further
    output.texCoord = input.TexCoord;
	
	return output;
}

//--- PixelShader ---

float4 DepthMapPS (VertexShaderOutput IN) : COLOR0
{
	float mask = tex2D(diffuseSampler, IN.texCoord).a;
	if (mask < 0.5)
		discard;
	
	return IN.depth.x / IN.depth.y;
}

float4 DepthMapLinearPS (VertexShaderOutput IN) : COLOR0
{
	float mask = tex2D(diffuseSampler, IN.texCoord).a;
	if (mask < 0.5)
		discard;
	
	float depth = IN.depth.x;
	return float4(depth, depth * depth, 0, 1);
}

//--- Techniques ---

technique Default
{
    pass P0
    {
		ZEnable = true;
        VertexShader = compile vs_3_0 DepthMapVS();
        PixelShader = compile ps_3_0 DepthMapPS();
    }
}

technique DefaultAnimated
{
    pass P0
    {
		ZEnable = true;
        VertexShader = compile vs_3_0 DepthMapSkinnedAnimation();
        PixelShader = compile ps_3_0 DepthMapPS();
    }
}

technique Linear
{
    pass P0
    {
		ZEnable = true;
        VertexShader = compile vs_3_0 DepthMapLinearVS();
        PixelShader = compile ps_3_0 DepthMapLinearPS();
    }
}

technique LinearAnimated
{
    pass P0
    {
		ZEnable = true;
        VertexShader = compile vs_3_0 DepthMapSkinnedAnimation();
        PixelShader = compile ps_3_0 DepthMapLinearPS();
    }
}		