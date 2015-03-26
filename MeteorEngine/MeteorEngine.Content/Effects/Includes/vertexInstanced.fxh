//-----------------------------------------
//	VertexInstanced
//-----------------------------------------

float4x4 World;
float4x4 View;
float4x4 Projection;
float4x4 inverseView;

// Light and camera properties
float3 CameraPosition;

struct VertexShaderInput
{
    float4 Position : POSITION0;
    float3 Normal : NORMAL0;
    float2 TexCoord : TEXCOORD0;
    float3 binormal : BINORMAL0;
    float3 tangent : TANGENT0;
    float4 boneIndices : BLENDINDICES0;
    float4 boneWeights : BLENDWEIGHT0;
};

struct VertexShaderOutput
{
    float4 Position : POSITION0;
    float2 TexCoord : TEXCOORD0;
    float3 Depth : TEXCOORD1;
    float3x3 TangentToWorld	: TEXCOORD2;
	float3 Reflection : TEXCOORD5;
	float4 NewPosition : TEXCOORD6;
};

struct InstanceInput
{
	float4 vWorld1 : TEXCOORD1;
	float4 vWorld2 : TEXCOORD2;
	float4 vWorld3 : TEXCOORD3;
	float4 vWorld4 : TEXCOORD4;
};

//--- VertexShaders ---//

VertexShaderOutput VertexShaderFunction(VertexShaderInput input, InstanceInput instance)
{
    VertexShaderOutput output;

	float4x4 wvp = mul(mul(World, View), Projection);
	float4x4 WorldInstance = 
		float4x4(instance.vWorld1, instance.vWorld2, instance.vWorld3, instance.vWorld4);

	// First transform by the instance matrix
    float4 worldPosition = mul(input.Position, WorldInstance);
    float4 viewPosition = mul(worldPosition, View);
	output.Position = mul(worldPosition, wvp);
	output.NewPosition = output.Position;

	//pass the texture coordinates further
    output.TexCoord = input.TexCoord;

	//get normal into world space
    input.Normal = normalize(mul(input.Normal, World));
    output.Depth.x = output.Position.z;// - 100.f; // Subtract to make color more visible
    output.Depth.y = output.Position.w;
	output.Depth.z = viewPosition.z;

    // calculate tangent space to world space matrix using the world space tangent,
    // binormal, and normal as basis vectors.
	output.TangentToWorld[0] = mul(normalize(mul(input.tangent, WorldInstance)), View);
    output.TangentToWorld[1] = mul(normalize(mul(input.binormal, WorldInstance)), View);
    output.TangentToWorld[2] = mul(normalize(mul(input.Normal, WorldInstance)), View);

	//if (output.TangentToWorld[2].z < 0)
	//	output.TangentToWorld[2] = -output.TangentToWorld[2];

    // Compute a reflection vector for the environment map.
	float3 ViewDirection = CameraPosition - output.Position;
    output.Reflection = reflect(normalize(ViewDirection), input.Normal);

    return output;
}

#define MaxBones 60
float4x4 bones[MaxBones];

VertexShaderOutput VertexShaderSkinnedAnimation(VertexShaderInput input, InstanceInput instance)
{
    VertexShaderOutput output;

	// Blend between the weighted bone matrices.
	float4x4 skinTransform = 0;
    
	skinTransform += bones[input.boneIndices.x] * input.boneWeights.x;
	skinTransform += bones[input.boneIndices.y] * input.boneWeights.y;
	skinTransform += bones[input.boneIndices.z] * input.boneWeights.z;
	skinTransform += bones[input.boneIndices.w] * input.boneWeights.w;

	input.Normal = mul(input.Normal, skinTransform);
	input.tangent = mul(input.tangent, skinTransform);
	input.binormal = mul(input.binormal, skinTransform);

	// Instancing transformation
	float4x4 wvp = mul(mul(World, View), Projection);
	float4x4 WorldInstance = 
		float4x4(instance.vWorld1, instance.vWorld2, instance.vWorld3, instance.vWorld4);

	float4 worldPosition = mul(mul(input.Position, skinTransform), WorldInstance);
    float4 viewPosition = mul(worldPosition, View);
    output.Position = mul(viewPosition, Projection);
	output.NewPosition = output.Position;

	//pass the texture coordinates further
    output.TexCoord = input.TexCoord;

	//get normal into world space
    input.Normal = normalize(mul(input.Normal, World));
    output.Depth.x = output.Position.z;// - 100.f; // Subtract to make color more visible
    output.Depth.y = output.Position.w;
	output.Depth.z = viewPosition.z;

    // calculate tangent space to world space matrix using the world space tangent,
    // binormal, and normal as basis vectors.
	output.TangentToWorld[0] = mul(normalize(mul(input.tangent, WorldInstance)), View);
    output.TangentToWorld[1] = mul(normalize(mul(input.binormal, WorldInstance)), View);
    output.TangentToWorld[2] = mul(normalize(mul(input.Normal, WorldInstance)), View);

    // Compute a reflection vector for the environment map.
	float3 ViewDirection = CameraPosition - output.Position;
    output.Reflection = reflect(normalize(ViewDirection), input.Normal);

    return output;
}