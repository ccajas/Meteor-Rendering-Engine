//-----------------------------------------
//	ForwardRender
//-----------------------------------------

// Light and camera properties
float3 lightDirection;
float4 lightColor;
float3 ambientTerm;
float3 camPosition;

texture Texture;
texture NormalMap;

sampler diffuseSampler : register(s0) = sampler_state
{
    Texture = <Texture>;
	Filter = MIN_MAG_MIP_LINEAR;
	AddressU = Wrap;
	AddressV = Wrap;
};

sampler normalMapSampler : register(s2) = sampler_state
{
    Texture = <NormalMap>;
	Filter = MIN_MAG_MIP_LINEAR;
	AddressU = Wrap;
	AddressV = Wrap;
};

#include "Includes/vertexInstanced.fxh"

//--- PixelShaders ---//

// Blinn D1 (Phong) specular distribution 
float BlinnPhong(float3 normal, float3 view, float3 light, float specPower)
{					
	float3 halfVector = normalize(light + view);
	return pow(saturate(dot(normal, halfVector)), specPower * 4);
}

float4 PixelShaderLighting(VertexShaderOutput input) : COLOR0
{
	// Output color
	// First check if this pixel is opaque
    float4 color = tex2D(diffuseSampler, input.TexCoord);
	clip(color.a - 0.5);

    // Output the normal, in [0,1] space
    float3 normalFromMap = tex2D(normalMapSampler, input.TexCoord);

    normalFromMap = mul(normalFromMap, input.TangentToWorld);	
    normalFromMap = normalize(normalFromMap);

	// Get normal data
	float3 normal = mul(normalFromMap, inverseView);
    
	// Get specular data
	float4 specular = float4(0.2, 0.2, 0.2, 0.1);

	// Compute diffuse light

	float3 lightDir = -normalize(lightDirection);
    float ndl = saturate(dot(normal, lightDir));
	float3 light = ndl * lightColor;

	// Calculate specular highlights
	float3 directionToCamera = normalize(camPosition - input.NewPosition);
	float specLight = specular.rgb * BlinnPhong(normal, directionToCamera, lightDir, specular.a);

	// Gamma encoding
	color.rgb *= color.rgb;
	float4 finalColor = float4(color.rgb * (ambientTerm + light) * lightColor.a, 1);

	// Add fog based on exponential depth
	float4 fogColor = float4(0.3, 0.5, 0.92, 1);

	float4 depth = input.Depth.x / input.Depth.y;  
	if (color.a > 0.499f)
		finalColor.rgb = lerp(finalColor.rgb, fogColor, pow(depth, 1000));

	// Gamma correct inverse
	finalColor.rgb = pow(finalColor.rgb, 1 / 2.f);
    
	return finalColor;
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

float4 SkyboxPS(VertexShaderOutput input) : COLOR0
{
    // Flag skybox output with zero alpha
	float4 color = tex2D(diffuseSampler, input.TexCoord);

	color.a = 0.49f;
	return color;
}

/// Very basic shaders ahead

float4 BasicPS(VertexShaderOutput input) : COLOR0
{
    // Simply return the input texture color
	return tex2D(diffuseSampler, input.TexCoord);
}

/// The following techniques draw a variation of forward rendering. 
/// Techniques used for skinned meshes simply use a different vertex shader to
/// handle bone tranformations.

technique ForwardRender
{
    pass Pass1
    {
	    ZEnable = true;
        VertexShader = compile vs_3_0 VertexShaderFunction();
        PixelShader = compile ps_3_0 PixelShaderLighting();
    }
}

technique ForwardRenderAnimated
{
    pass Pass1
    {
	    ZEnable = true;
        VertexShader = compile vs_3_0 VertexShaderSkinnedAnimation();
        PixelShader = compile ps_3_0 PixelShaderLighting();
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
