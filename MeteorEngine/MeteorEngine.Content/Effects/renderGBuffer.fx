//-----------------------------------------
//	RenderGBuffer
//-----------------------------------------

texture Texture;
texture NormalMap;
texture SpecularMap;
texture EnvironmentMap;

sampler diffuseSampler : register(s0) = sampler_state
{
    Texture = <Texture>;
    MagFilter = Linear;
    MinFilter = Anisotropic;
    MipFilter = Linear;
	AddressU = Wrap;
	AddressV = Wrap;
};

sampler specularSampler : register(s1) = sampler_state
{
    Texture = <SpecularMap>;
    MagFilter = Linear;
    MinFilter = Anisotropic;
    MipFilter = Linear;
	AddressU = Wrap;
	AddressV = Wrap;
};

sampler normalMapSampler : register(s2) = sampler_state
{
    Texture = <NormalMap>;
    MagFilter = Linear;
    MinFilter = Anisotropic;
    MipFilter = Linear;
	AddressU = Wrap;
	AddressV = Wrap;
};

sampler environmentMapSampler : register(s3) = sampler_state
{
    Texture = <EnvironmentMap>;
    MagFilter = Linear;
    MinFilter = Anisotropic;
    MipFilter = Linear;
	AddressU = Mirror; 
	AddressV = Mirror; 
};

#include "Includes/vertexInstanced.fxh"

//--- PixelShaders ---//

struct PixelShaderOutput1
{
    float4 Normal : COLOR0;
    float4 Depth : COLOR1;
    float4 Color : COLOR2;
};

struct PixelShaderOutput2
{
    half4 Normal : COLOR0;
    half4 Depth : COLOR1;
};

PixelShaderOutput1 PixelShaderGBuffer(VertexShaderOutput input)
{
    PixelShaderOutput1 output;

	// Output Color
	// First check if this pixel is opaque
    output.Color = tex2D(diffuseSampler, input.TexCoord);
	clip(output.Color.a - 0.5);

    // Output the normal, in [0,1] space
    float3 normalFromMap = tex2D(normalMapSampler, input.TexCoord);

    normalFromMap = mul(normalFromMap, input.TangentToWorld);	
    normalFromMap = normalize(normalFromMap);
    output.Normal.rgb = 0.5f * (normalFromMap + 1.0f);

	// Output SpecularPower and SpecularIntensity
	float4 specularAttributes = tex2D(specularSampler, input.TexCoord);
    output.Normal.a = specularAttributes.r;

	// Output Depth
	output.Depth = input.Depth.x / input.Depth.y;  
    return output;
}

PixelShaderOutput2 PixelShaderSmallGBuffer(VertexShaderOutput input)
{
    PixelShaderOutput2 output = (PixelShaderOutput2)1;

	// First check if this pixel is opaque
	float mask = tex2D(diffuseSampler, input.TexCoord).a;
	clip(mask - 0.5);

    // Output the normal, in [0,1] space
    float3 normalFromMap = tex2D(normalMapSampler, input.TexCoord);

    normalFromMap = mul(normalFromMap, input.TangentToWorld);	
    //normalFromMap = normalize(normalFromMap);
    output.Normal.rgb = 0.5f * (normalFromMap + 1.0f);

	// Output SpecularPower
	// Output SpecularIntensity
	float4 specularAttributes = tex2D(specularSampler, input.TexCoord);
    output.Normal.a = specularAttributes.r; //specularIntensity;

	// Output Depth
	output.Depth = input.Depth.x / input.Depth.y; 
    return output;
}

float4 PixelShaderDiffuseRender(VertexShaderOutput input) : COLOR0
{
	// First check if mask channel is opaque
	float4 diffuse = tex2D(diffuseSampler, input.TexCoord);
	clip(diffuse.a - 0.5);

	float3 envmap = texCUBE(environmentMapSampler, normalize(input.Reflection));

    // Output the normal, in [0,1] space
    float3 normalFromMap = tex2D(normalMapSampler, input.TexCoord);

    normalFromMap = mul(normalFromMap, input.TangentToWorld);	
    normalFromMap = normalize(normalFromMap);

	// Compute a fresnel coefficient from the view vector.
	//float3 ViewDirection = CameraPosition - input.NewPosition;
	//float fresnel = saturate(1 + dot(normalize(ViewDirection), normalFromMap));

	// Just output the diffuse color
	return diffuse;//float4(lerp(diffuse, envmap, pow(fresnel, 2) * 0.7f), 1);
}

/// Very basic shaders ahead

float2 halfPixel;

struct VertexShaderBasic
{
    float4 Position : POSITION0;
	float2 TexCoord : TEXCOORD0;
};

struct VertexShaderNormalBasic
{
    float4 Position : POSITION0;
	float2 TexCoord : TEXCOORD0;
	float3 Normal : TEXCOORD1;
};

VertexShaderBasic BasicVS(
	float3 position : POSITION0, float2 texCoord : TEXCOORD0)
{
    VertexShaderBasic output;

	// Just pass these through
    output.Position = float4(position, 1);
	output.TexCoord = texCoord + halfPixel;

    return output;
}

VertexShaderNormalBasic BasicMeshVS(
	InstanceInput instance,
	in float3 position : POSITION0, 
	in float2 texCoord : TEXCOORD0)
{
    VertexShaderNormalBasic output;

	float4x4 wvp = mul(mul(World, View), Projection);
	float4x4 WorldInstance = 
		float4x4(instance.vWorld1, instance.vWorld2, instance.vWorld3, instance.vWorld4);

	// First transform by the instance matrix
    float4 worldPosition = mul(position, WorldInstance);

	// Set the outputs
	output.Position = mul(worldPosition, wvp);
	output.Normal = 0;// mul(normalize(mul(normal, WorldInstance)), View);
	output.TexCoord = texCoord + halfPixel;

    return output;
}

float4 BasicPS(VertexShaderOutput input) : COLOR0
{
    // Simply return the input texture color
	return tex2D(diffuseSampler, input.TexCoord);
}

float4 PS_White() : COLOR0
{
	return float4(1, 1, 1, 1);
}

//--- Skybox shader ---//

struct VertexShaderSkyboxData
{
    float4 Position : POSITION0;
	float2 TexCoord : TEXCOORD0;
};

VertexShaderSkyboxData VertexShaderSkybox(VertexShaderInput input, InstanceInput instance)
{
    VertexShaderSkyboxData output;

	float4x4 WorldInstance = 
		float4x4(instance.vWorld1, instance.vWorld2, instance.vWorld3, instance.vWorld4);

	//handle the position as direction
	float4 hPos = mul(input.Position, WorldInstance);//,0);
	float4x4 wvp = mul(mul(World, View), Projection);
 
	//we should set z and w to the same value, so we will have the skybox at the far plane 
    output.Position = mul(hPos, wvp);//.xyzw;
	output.TexCoord = input.TexCoord;

	return output;
}

PixelShaderOutput1 SkyboxPS(VertexShaderOutput input) : COLOR0
{
	PixelShaderOutput1 output;

    // Flag skybox output with zero alpha
	float4 color = tex2D(diffuseSampler, input.TexCoord);

	color.a = 0.49f;
	output.Color = color;

	// No normal mapping, pushes the skybox way to the far plane
	output.Normal = 0.5f;
	output.Depth = 0.999995f;

	return output;
}

/// The following four techniques draw a variation of the GBuffer, 
/// either with two render targets (light pre-pass) or three render 
/// targets (deferred) simultaneously. Techniques used for skinned meshes 
/// simply use a different vertex shader to handle bone tranformations.

technique GBuffer
{
    pass Pass1
    {
	    ZEnable = true;
        VertexShader = compile vs_3_0 VertexShaderFunction();
        PixelShader = compile ps_3_0 PixelShaderGBuffer();
    }
}

technique GBufferAnimated
{
    pass Pass1
    {
	    ZEnable = true;
        VertexShader = compile vs_3_0 VertexShaderSkinnedAnimation();
        PixelShader = compile ps_3_0 PixelShaderGBuffer();
    }
}

technique SmallGBuffer
{
    pass Pass1
    {
	    ZEnable = true;
        VertexShader = compile vs_3_0 VertexShaderFunction();
        PixelShader = compile ps_3_0 PixelShaderSmallGBuffer();
    }
}

technique SmallGBufferAnimated
{
    pass Pass1
    {
	    ZEnable = true;
        VertexShader = compile vs_3_0 VertexShaderSkinnedAnimation();
        PixelShader = compile ps_3_0 PixelShaderSmallGBuffer();
    }
}

/// Separately render the diffuse/albedo component to combine, for light pre-pass.

technique DiffuseRender
{
    pass Pass1
    {
	    ZEnable = true;
        VertexShader = compile vs_2_0 VertexShaderFunction();
        PixelShader = compile ps_2_0 PixelShaderDiffuseRender();
    }
}

technique DiffuseRenderAnimated
{
    pass Pass1
    {
	    ZEnable = true;
        VertexShader = compile vs_2_0 VertexShaderSkinnedAnimation();
        PixelShader = compile ps_2_0 PixelShaderDiffuseRender();
    }
}

technique Skybox
{
    pass Pass1
    {
		CullMode = None;
	    ZEnable = true;
		ZFunc = LessEqual;
		ZWriteEnable = false;
		
        VertexShader = compile vs_3_0 VertexShaderSkybox();
        PixelShader = compile ps_3_0 SkyboxPS();
    }
}

/// Copy a render target straight as is

technique PassThrough
{
    pass Pass1
    {
        VertexShader = compile vs_2_0 BasicVS();
        PixelShader = compile ps_2_0 BasicPS();
    }
}

technique BasicMesh
{
    pass Pass1
    {
        VertexShader = compile vs_2_0 BasicMeshVS();
        PixelShader = compile ps_2_0 BasicPS();
    }
}
