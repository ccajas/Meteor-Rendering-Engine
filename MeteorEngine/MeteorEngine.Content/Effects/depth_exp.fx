//-----------------------------------------
//	DepthMap
//-----------------------------------------

//--- Parameters ---

float4x4 World;
float4x4 LightViewProj;
float farClip;

texture Texture;
sampler diffuseSampler : register(s0);

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
	float4 worldPos : TEXCOORD1;
	float depth : TEXCOORD2;
};

//--- VertexShader ---

VertexShaderOutput DepthMapVS(VertexShaderInput input)
{
	VertexShaderOutput output;

	float4 position = input.Position;
	
	output.position = mul(position, mul(World, LightViewProj));
	output.worldPos = output.position;
	output.depth = output.position.z / farClip;//output.position.w;

	//pass the texture coordinates further
    output.texCoord = input.TexCoord;
	
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
	output.worldPos = output.position;
	output.depth = output.position.z / output.position.w;

	//pass the texture coordinates further
    output.texCoord = input.TexCoord;
	
	return output;
}

//--- PixelShader ---

float4 DepthMapPS (VertexShaderOutput IN) : COLOR0
{
	float4 mask = tex2D(diffuseSampler, IN.texCoord);
	//clip(mask.a - 0.5);

	return IN.depth;

	float moment1 = IN.depth;
	float moment2 = IN.depth * IN.depth;
	
	// Adjusting moments (this is sort of bias per pixel) using partial derivative
	float dx = ddx(IN.depth);
	float dy = ddy(IN.depth);
	moment2 += clamp(0.25 * (dx * dx + dy * dy), 0, 1);
	
    return float4(moment1, moment2, 1.0f, 1.0f);
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