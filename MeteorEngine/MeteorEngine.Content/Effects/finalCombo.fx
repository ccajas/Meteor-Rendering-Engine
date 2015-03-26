
float4x4 World;
float4x4 View;
float4x4 Projection;

float2 halfPixel;
float ambient;
float flicker;
float includeSSAO;

texture diffuseMap;
texture ssaoMap;
texture lightMap;

sampler diffuseSampler : register(s0) = sampler_state
{
	Filter = MIN_MAG_MIP_LINEAR;
	AddressU = Wrap;
	AddressV = Wrap;
	Texture = <diffuseMap>;
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
	Filter = MIN_MAG_MIP_LINEAR;
	AddressU = Wrap;
	AddressV = Wrap;
	Texture = <ssaoMap>;
};

struct VertexShaderInput
{
    float3 Position : POSITION0;
	float2 TexCoord : TEXCOORD0;
};

struct VertexShaderOutput
{
    float4 Position : POSITION0;
	float2 TexCoord : TEXCOORD0;
};

float g_fMiddleGrey = 0.6f; 
float g_fMaxLuminance = 16.0f; 

static const float3 LUM_CONVERT = float3(0.299f, 0.587f, 0.114f); 

float3 ToneMap(float3 vColor) 
{
	// Get the calculated average luminance 
	float fLumAvg = 0.03f;//tex2D(diffuseSampler, float2(0.5f, 0.5f)).r;     

	// Calculate the luminance of the current pixel 
	float fLumPixel = dot(vColor, LUM_CONVERT);     

	// Apply the modified operator (Eq. 4) 
	float fLumScaled = (fLumPixel * g_fMiddleGrey) / fLumAvg;     
	float fLumCompressed = (fLumScaled * (1 + (fLumScaled / (g_fMaxLuminance * g_fMaxLuminance)))) / (1 + fLumScaled); 
	return fLumCompressed * vColor; 
} 

VertexShaderOutput VertexShaderFunction(VertexShaderInput input)
{
    VertexShaderOutput output;

	// Just pass these through
    output.Position = float4(input.Position, 1);
	output.TexCoord = input.TexCoord + halfPixel;

    return output;
}

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
	float4 light = saturate(tex2D(lightSampler, input.TexCoord));

	// This ensures that the specular highlight is of the right color
	float3 specular = light.rgb * light.a;

	float4 ssao = 1;
	if (includeSSAO >= 1)
	{
		ssao = tex2D(ssaoSampler, input.TexCoord);
	}
	light *= ssao;
	float amb = ambient;// * ssao;
	//return ssao;

	float3 finalColor = (float3)0;
	finalColor = light.rgb * diffuse + (light * specular);

	return float4(finalColor * (0.95f + flicker * 0.05f), 1);
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
        VertexShader = compile vs_2_0 VertexShaderFunction();
        PixelShader = compile ps_2_0 PixelShaderStippled();
    }
}
