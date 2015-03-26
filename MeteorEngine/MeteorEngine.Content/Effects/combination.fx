//-----------------------------------------
//	Combination
//-----------------------------------------

float4x4 World;
float4x4 View;
float4x4 Projection;

float2 halfPixel;
float includeSSAO;

// Combined textures
texture diffuseMap;
texture ssaoMap;
texture lightMap;
texture depthMap;

sampler diffuseSampler : register(s0) = sampler_state
{
	Filter = MIN_MAG_MIP_LINEAR;
	AddressU = Wrap;
	AddressV = Wrap;
	Texture = <diffuseMap>;
};

sampler depthSampler : register(s1) = sampler_state
{
	Filter = MIN_MAG_MIP_POINT;
	AddressU = Wrap;
	AddressV = Wrap;
	Texture = <depthMap>;
};

sampler lightSampler : register(s4) = sampler_state
{
	Filter = MIN_MAG_MIP_POINT;
	AddressU = Wrap;
	AddressV = Wrap;
	Texture = <lightMap>;
};

sampler ssaoSampler : register(s5) = sampler_state
{
	Filter = MIN_MAG_MIP_POINT;
	AddressU = Wrap;
	AddressV = Wrap;
	Texture = <ssaoMap>;
};

#include "Includes/screenQuad.fxh"

// Helper for modifying the saturation of a color.
float4 AdjustSaturation(float4 color, float saturation)
{
    // The constants 0.3, 0.59, and 0.11 are chosen because the
    // human eye is more sensitive to green light, and less to blue.
    float grey = dot(color, float3(0.3, 0.59, 0.11));

    return lerp(grey, color, saturation);
}

float4 PixelShaderFunction(VertexShaderOutput input) : COLOR0
{	
    // Combine texture with light map
	float4 diffuse = tex2D(diffuseSampler, input.TexCoord);
	float4 light = tex2D(lightSampler, input.TexCoord);

	// Gamma encoding
	diffuse.rgb *= diffuse.rgb;

	float4 ssao = 1;
	if (includeSSAO >= 1)
		ssao = tex2D(ssaoSampler, input.TexCoord);

	light *= ssao;

	float4 finalColor = float4((light.rgb * diffuse) + normalize(light.rgb) * light.a, diffuse.a);

	// Add fog based on exponential depth
	float4 fogColor = float4(0.3, 0.5, 0.92, 1);

	float depth = tex2D(depthSampler, input.TexCoord);
	if (diffuse.a > 0.499f)
		finalColor.rgb = lerp(finalColor.rgb, fogColor, pow(depth, 1000));

	// Gamma correct inverse
	finalColor.rgb = pow(finalColor.rgb, 1 / 2.f);
	finalColor.a = 1;

	return finalColor;
}

const float horizontalStep = 1.0 / 1280.0f;
const float verticalStep = 1.0 / 720.0f;

float4 PixelShaderStippled(VertexShaderOutput input) : COLOR0
{
    // Combine texture with light map
	float3 diffuse = tex2D(diffuseSampler, input.TexCoord).rgb;
	float4 lightMap = tex2D(lightSampler, input.TexCoord);

	float4 light = lightMap;
	float specular = lightMap.r;
	
	half2 stippleOffset;
	stippleOffset.x = frac(input.TexCoord.x * 640);
	stippleOffset.y = frac(input.TexCoord.y * 360);

	float leftCoord = input.TexCoord.x - horizontalStep;
	float rightCoord = input.TexCoord.x + horizontalStep;
	float topCoord = input.TexCoord.y - verticalStep;
	float bottomCoord = input.TexCoord.y + verticalStep;

	float4 lightMaps[5];

	lightMaps[0] = tex2D(lightSampler, input.TexCoord);
	lightMaps[1] = tex2D(lightSampler, float2(leftCoord, input.TexCoord.y));
	lightMaps[2] = tex2D(lightSampler, float2(rightCoord, input.TexCoord.y));
	lightMaps[3] = tex2D(lightSampler, float2(input.TexCoord.x, topCoord));
	lightMaps[4] = tex2D(lightSampler, float2(input.TexCoord.x, bottomCoord));
	
	float matched = floor(step(0.25, abs(stippleOffset.x - stippleOffset.y)));
	if (step(0.25, abs(stippleOffset.x - stippleOffset.y)) >= 1.0f)
	{
		light = 0;// *= (1 - matched);
		for(int i = 0; i < 4; i++)
		{
			light += lightMaps[i + 1];// *= (1 - matched);
		}
		light /= 4.0f;
	}

	float ambient = 0.15;
	float3 finalColor = (light * diffuse * (1 + ambient) ) + light * specular;
	float luma = dot(finalColor, float3(0.299, 0.587, 0.114)); // compute luma
	return float4(finalColor, luma);
}

technique Technique1
{
    pass Pass0
    {
        VertexShader = compile vs_3_0 VertexShaderFunction();
        PixelShader = compile ps_3_0 PixelShaderFunction();
    }
}

technique Technique2
{
    pass Pass0
    {
        VertexShader = compile vs_3_0 VertexShaderFunction();
        PixelShader = compile ps_3_0 PixelShaderStippled();
    }
}
