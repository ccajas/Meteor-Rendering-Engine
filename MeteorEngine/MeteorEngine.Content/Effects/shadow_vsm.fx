//-----------------------------------------
//	ShadowMap
//-----------------------------------------

//------------------
//--- Parameters ---
float4x4 World;
float4x4 View;
float4x4 Projection;
float4x4 LightViewProj;
shared float4 xLightPos;
shared float xLightPower;
shared float farClip;

bool TextureEnabled;

texture Texture;
sampler ModelTextureSampler = sampler_state
{
    Texture = <Texture>;
};

texture ShadowMap;
sampler ShadowMapSampler = sampler_state
{
	Filter = MIN_MAG_MIP_LINEAR;
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
	float2 RealDistance : TEXCOORD2;
};

struct PixelShaderInput
{
	float4 Color : COLOR0;
	float2 TexCoord : TEXCOORD0;
	float4 ShadowMapPos	: TEXCOORD1;
	float2 RealDistance : TEXCOORD2;
};

//--------------------
//--- VertexShader ---
VertexShaderOutput VertexShaderFunction(VertexShaderInput input)
{
	VertexShaderOutput output;
	float4x4 wvp =  mul(mul(World, View), Projection);

	output.Position = mul(input.Position, wvp);
    float4 worldPos = mul(input.Position, World);
	output.ShadowMapPos = mul(worldPos, LightViewProj);
	
	output.RealDistance.x = output.ShadowMapPos.z / farClip;
	output.RealDistance.y = output.ShadowMapPos.z / output.ShadowMapPos.w;
 
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
	float4 worldPos = mul(position, World);
	output.ShadowMapPos = mul(worldPos, LightViewProj);
	
	output.RealDistance.x = output.ShadowMapPos.z / farClip;
	output.RealDistance.y = output.ShadowMapPos.z / output.ShadowMapPos.w;
 
    output.TexCoord = input.TexCoord;
	
	return output;
}

//-------------------
//--- PixelShader ---

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
    float2 ProjectedTexCoords;

	//projected texture coordinate
	//float3 lookupCoord = input.ShadowMapPos.xyz / input.ShadowMapPos.w;
    
    ProjectedTexCoords.x = input.ShadowMapPos.x / input.ShadowMapPos.w / 2.0f + 0.5f;
	ProjectedTexCoords.y = -input.ShadowMapPos.y / input.ShadowMapPos.w / 2.0f + 0.5f;
	/*
	//convert the shadow map projection XY into texture range (so convert from [-1,1] to [0,1])
	//ProjectedTexCoords = lookupCoord.xy * float2(0.5,-0.5) + 0.5;

	//sample the shadow map
	float occlusion = tex2D(ShadowMapSampler, ProjectedTexCoords).r;
	
	//apply a small bias, to account for sampling errors
	float receiver = lookupCoord.z - 0.001;
	
	//difference with real depth
	float difference = occlusion - receiver;
	
	//shadow term
	float shadow = occlusion / exp(input.RealDistance.x * receiver);
	
	//sample texture
	float3 color = 1;
	color *= shadow;
	
	return float4(color, 1);
	*/
	float mask = tex2D(ModelTextureSampler, input.TexCoord).a;

    if ((saturate(ProjectedTexCoords.x) == ProjectedTexCoords.x) && 
		(saturate(ProjectedTexCoords.y) == ProjectedTexCoords.y) && (mask > 0.5))
	{
		// Process what's in the light view
		float len = input.RealDistance.x;		
		float2 moments = tex2D(ShadowMapSampler, ProjectedTexCoords);
	
		// The fragment is either in shadow or penumbra. We now use chebyshev's upperBound to check
		// How likely this pixel is to be lit (pMax)

		float variance = moments.y - (moments.x * moments.x);
		variance = max(variance, 0.0004f);
	
		// Mean distance
		float d = len - moments.x;
		float pMax = variance / (variance + d * d);

		// Reduce light bleeding
		float min = 3.0f;
		float3 step = smoothstep(0.3, 1, pMax) + 0.35f;

		return float4(step, input.RealDistance.y / farClip);
	}
	else
	{
		if (mask < 0.5)
			discard;

		// Whatever's outside the light view
		return float4(1, 1, 1, input.RealDistance.y / farClip);
	}
}

float DepthBias = 0.02f;

float4 PixelShaderSimple(PixelShaderInput input) : COLOR
{
    // Color of the model
    float4 diffuse = 1;
    
    // Find the position in the shadow map for this pixel
    float2 ShadowTexCoord = input.ShadowMapPos.xy / input.ShadowMapPos.w / 2.0f + float2( 0.5, 0.5 );
    ShadowTexCoord.y = 1 - ShadowTexCoord.y;

	//ShadowTexCoord.x = input.ShadowMapPos.x / input.ShadowMapPos.w / 2.0f + 0.5f;
    //ShadowTexCoord.y = -input.ShadowMapPos.y / input.ShadowMapPos.w / 2.0f + 0.5f;

    // Get the current depth stored in the shadow map
    float shadowdepth = tex2D(ShadowMapSampler, ShadowTexCoord).r;    
    
    // Calculate the current pixel depth
    // The bias is used to prevent floating point errors that occur when
    // the pixel of the occluder is being drawn
    float ourdepth = (input.ShadowMapPos.z / input.ShadowMapPos.w) - DepthBias;
    
    // Check to see if this pixel is in front or behind the value in the shadow map
    if (ourdepth > shadowdepth)
    {
        // Shadow the pixel by lowering the intensity
        diffuse *= float4(0.5,0.5,0.5,1);
    };
    
    return diffuse;
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