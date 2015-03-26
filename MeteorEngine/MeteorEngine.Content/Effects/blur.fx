
float4x4 World;
float4x4 View;
float4x4 Projection;

const float2 halfPixel;
const float saturation;
const float contrast;

texture diffuseMap;
texture blurMap;
texture depthMap;

sampler diffuseSampler : register (s0) = sampler_state
{
	Filter = MIN_MAG_MIP_LINEAR;
	AddressU = Clamp;
	AddressV = Clamp;
	Texture = <diffuseMap>;
};

sampler blurSampler : register (s1) = sampler_state
{
	Filter = MIN_MAG_MIP_LINEAR;
	AddressU = Clamp;
	AddressV = Clamp;
	Texture = <blurMap>;
};

sampler depthSampler : register (s4) = sampler_state
{
	Filter = MIN_MAG_MIP_POINT;
	AddressU = Clamp;
	AddressV = Clamp;
	Texture = <depthMap>;
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

VertexShaderOutput VertexShaderFunction(VertexShaderInput input)
{
    VertexShaderOutput output;

	// Just pass these through
    output.Position = float4(input.Position, 1);
	output.TexCoord = input.TexCoord + halfPixel;

    return output;
}

// This will set how many texture samples to blur from.
// If you want a larger blur change the sample_count to a higher odd number.

#define SAMPLE_COUNT 9

uniform extern half4 sampleOffsets[SAMPLE_COUNT];
uniform extern half sampleWeights[SAMPLE_COUNT];

// The Y luminance transformation used follows that used by TIFF and JPEG (Rec 601-1)

const float3 luminanceFilter = { 0.2989, 0.5866, 0.1145 };
const float sharp = 0.75f;
const float stepDownsizeFactor;
const float threshold;
const float bloomFactor;

float4 PixelGaussianBlur(VertexShaderOutput input) : COLOR0
{	
	float4 sum = 0.0f;

	// Get the center texel offset and weight

	[unroll(SAMPLE_COUNT)]
	for(int i = 0; i < SAMPLE_COUNT; i++) 
	{
		sum += tex2D(diffuseSampler, input.TexCoord + sampleOffsets[i].xy) * sampleWeights[i];
	}

	return sum;
}

float4 QuickBlur(VertexShaderOutput input) : COLOR0
{
	float4 sum;
	float depthVal = tex2D(depthSampler, input.TexCoord);

	float hStep = 1.0 / (1280.0f * stepDownsizeFactor) * depthVal;
	float vStep = 1.0 / (720.0f * stepDownsizeFactor) * depthVal;

	sum =  tex2D(diffuseSampler, float2(input.TexCoord.x + hStep, input.TexCoord.y + vStep));
	sum += tex2D(diffuseSampler, float2(input.TexCoord.x - hStep, input.TexCoord.y - vStep));
	sum += tex2D(diffuseSampler, float2(input.TexCoord.x + hStep, input.TexCoord.y - vStep));
	sum += tex2D(diffuseSampler, float2(input.TexCoord.x - hStep, input.TexCoord.y + vStep));

	return sum / 4.f;
}

const float focalDistance;
const float focalRange;
const float near = 0.001;
const float far = 0.999;

float4 DepthOfFieldFull(VertexShaderOutput input) : COLOR0
{
	half4 sharpScene = tex2D(diffuseSampler, input.TexCoord);
	half4 blurScene = tex2D(blurSampler, input.TexCoord);
	float depthVal = tex2D(depthSampler, input.TexCoord);
	
	half dFar = far / (far - near);
	half fSceneZ = (-near * dFar) / (depthVal - dFar);
	float blurFactor = saturate(abs(fSceneZ - focalDistance) / focalRange);

	sharpScene.a = 1;
	blurScene.a = 1;

	return lerp (sharpScene, blurScene, blurFactor);
}

float4 DepthOfFieldImproved(VertexShaderOutput input) : COLOR0
{
	float4 sharpScene = tex2D(diffuseSampler, input.TexCoord);
	float4 blurScene = tex2D(blurSampler, input.TexCoord);
	float4 blurFactors = tex2D(depthSampler, input.TexCoord);

	//return blurFactors;
	return lerp (sharpScene, blurScene, saturate(blurFactors));

	float depth = tex2D(depthSampler,input.TexCoord.xy).r;
}

float g_fMiddleGrey = 0.6f; 
float g_fMaxLuminance = 16.0f; 

static const float3 LUM_CONVERT = float3(0.299f, 0.587f, 0.114f); 

float3 ToneMap(float3 vColor) 
{
	// Get the calculated average luminance 
	float fLumAvg = 0.25f;//tex2D(diffuseSampler, float2(0.5f, 0.5f)).r;     

	// Calculate the luminance of the current pixel 
	float fLumPixel = dot(vColor, LUM_CONVERT);     

	// Apply the modified operator (Eq. 4) 
	float fLumScaled = (fLumPixel * g_fMiddleGrey) / fLumAvg;     
	float fLumCompressed = (fLumScaled * 
		(1 + (fLumScaled / (g_fMaxLuminance * g_fMaxLuminance)))) / (1 + fLumScaled); 
	return fLumCompressed * vColor; 
} 

float4 SetThreshold(VertexShaderOutput input) : COLOR0
{
	float4 blurScene = tex2D(blurSampler, input.TexCoord);

	float greyLevel = saturate(mul(blurScene, luminanceFilter));
	float3 desaturated = lerp(blurScene, greyLevel, threshold);

	float normalizationFactor = 1 / (1 - threshold);
	return float4((desaturated - threshold) * normalizationFactor, 1);
}

// Helper for modifying the saturation of a color.
float4 AdjustSaturation(float4 color, float saturation)
{
    // The constants 0.3, 0.59, and 0.11 are chosen because the
    // human eye is more sensitive to green light, and less to blue.
    float grey = dot(color, float3(0.3, 0.59, 0.11));

    return lerp(grey, color, saturation);
}

float4 AddBloom(VertexShaderOutput input) : COLOR0
{
	float4 combinedBloom = tex2D(blurSampler, input.TexCoord);
	float4 frameBufferSample = tex2D(diffuseSampler, input.TexCoord);
	float4 original = frameBufferSample;

    combinedBloom = AdjustSaturation(combinedBloom, saturation) * bloomFactor;
    frameBufferSample = AdjustSaturation(frameBufferSample, saturation);
    frameBufferSample *= (1 - saturate(combinedBloom));
    
    // Combine the two images.
	return pow(frameBufferSample + combinedBloom, contrast);
}

technique QuickDOF
{
    pass Pass1
    {
        VertexShader = compile vs_2_0 VertexShaderFunction();
        PixelShader = compile ps_2_0 QuickBlur();
    }
}

technique DepthOfField
{
    pass Pass1
    {
        VertexShader = compile vs_2_0 VertexShaderFunction();
        PixelShader = compile ps_2_0 DepthOfFieldFull();
    }
}

technique ImprovedDOF
{
    pass Pass1
    {
        VertexShader = compile vs_2_0 VertexShaderFunction();
        PixelShader = compile ps_2_0 DepthOfFieldImproved();
    }
}

technique GaussianBlur
{
    pass Pass1
    {
        VertexShader = compile vs_3_0 VertexShaderFunction();
        PixelShader = compile ps_3_0 PixelGaussianBlur();
    }

    pass Pass2
    {
        VertexShader = compile vs_3_0 VertexShaderFunction();
        PixelShader = compile ps_3_0 PixelGaussianBlur();
    }

    pass Pass1
    {
        VertexShader = compile vs_3_0 VertexShaderFunction();
        PixelShader = compile ps_3_0 PixelGaussianBlur();
    }

    pass Pass2
    {
        VertexShader = compile vs_3_0 VertexShaderFunction();
        PixelShader = compile ps_3_0 PixelGaussianBlur();
    }
}

technique SimpleBloom
{
    pass Pass1
    {
        VertexShader = compile vs_2_0 VertexShaderFunction();
        PixelShader = compile ps_2_0 SetThreshold();
    }	

    pass Pass2
    {
        VertexShader = compile vs_3_0 VertexShaderFunction();
        PixelShader = compile ps_3_0 PixelGaussianBlur();
    }

    pass Pass3
    {
        VertexShader = compile vs_3_0 VertexShaderFunction();
        PixelShader = compile ps_3_0 PixelGaussianBlur();
    }

    pass Pass4
    {
        VertexShader = compile vs_2_0 VertexShaderFunction();
        PixelShader = compile ps_2_0 AddBloom();
    }
}