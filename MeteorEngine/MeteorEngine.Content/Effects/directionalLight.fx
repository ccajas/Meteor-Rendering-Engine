//-----------------------------------------
//	DirectionalLight
//-----------------------------------------

float4x4 View;
float4x4 Projection;
float4x4 inverseView;
float4x4 invertViewProj;

float2 halfPixel;
float3 camPosition;

// Cascaded shadow map settings

#define NUM_CASCADES 4
#define MAPS_PER_ROW 2
#define MAPS_PER_COL 2

const float shadowMapSize;
const float2 shadowMapPixelSize;

float4x4 lightViewProj[NUM_CASCADES];
float cascadeSplits[NUM_CASCADES];

// Directional light pass

float3 lightDirection;
float3 lightColor;
float3 ambientTerm;
float lightIntensity;

// Apply textures to the lighting

texture depthMap;
texture normalMap;
texture shadowMap;
texture specularMap;

sampler normalSampler : register(s1) = sampler_state
{
	Texture = <normalMap>;
	Filter = MIN_MAG_MIP_LINEAR;
	AddressU = Wrap;
	AddressV = Wrap;
};

sampler specularSampler : register(s2) = sampler_state
{
    Texture = <specularMap>;
	Filter = MIN_MAG_MIP_LINEAR;
	AddressU = Wrap;
	AddressV = Wrap;
};

sampler depthSampler : register(s4) = sampler_state
{
	Filter = MIN_MAG_MIP_POINT;
	AddressU = Clamp;
	AddressV = Clamp;
	Texture = <depthMap>;
};

sampler shadowMapSampler = sampler_state
{
	Filter = MIN_MAG_MIP_POINT;
	AddressU = Clamp;
	AddressV = Clamp;
	Texture = <shadowMap>;
};

#include "Includes/screenQuad.fxh"
#include "Includes/shadows.fxh"

// Blinn D1 (Phong) specular distribution 
float BlinnPhong(float3 normal, float3 view, float3 light, float specPower)
{					
	float3 halfVector = normalize(light + view);
	return pow(saturate(dot(normal, halfVector)), specPower);
}

float4 DirectionalLightPS(VertexShaderOutput input, float4 position) : COLOR0
{
	// Get normal data

	float4 normalData = tex2D(normalSampler, input.TexCoord);
	float3 normal = mul((2.0f * normalData.xyz - 1.0f), inverseView);

	// Get specular data

	float4 specular = tex2D(specularSampler, input.TexCoord);
	float specPower = specular.a * 255;
	float3 specIntensity = specular.rgb;

	float3 lightDir = -normalize(lightDirection);

	// Reflection data

	float3 reflection = normalize(reflect(-lightDir, normal)); 
	float3 directionToCamera = normalize(camPosition - position);

	// Compute the final specular factor
	// Compute diffuse light
	
	float3 halfVector = normalize(lightDir + directionToCamera);
	float ndh = saturate(dot(normal, halfVector));
	float ndl = saturate(dot(normal, lightDir));

	float3 diffuse = ndl * lightColor;

	float specLight = specIntensity * BlinnPhong(normal, directionToCamera, lightDir, specPower);
	//pow(saturate(dot(reflection, directionToCamera)), specPower);

	return float4((ambientTerm + diffuse) * lightIntensity, specLight * lightIntensity);
}

float4 CalculateWorldPosition(float2 texCoord, float depthVal)
{
	// Convert position to world space
	float4 position;

	position.xy = texCoord.x * 2.0f - 1.0f;
	position.y = -(texCoord.y * 2.0f - 1.0f);
	position.z = depthVal;
	position.w = 1.0f;

	position = mul(position, invertViewProj);
	position /= position.w;

	return position;
}

float4 PixelShaderFunction(VertexShaderOutput input) : COLOR0
{
	float depthVal = tex2D(depthSampler, input.TexCoord).r;

	if (depthVal > 0.99999f)
		return float4(1, 1, 1, 0);

	// Convert position to world space
	float4 position = CalculateWorldPosition(input.TexCoord, depthVal);

	// Calculate light color
	float4 lightOutput = DirectionalLightPS(input, position);

	return lightOutput;
}

float4 PixelShaderShadowed(VertexShaderOutput input) : COLOR0
{	
	float depthVal = tex2D(depthSampler, input.TexCoord).r;

	if (depthVal > 0.99999f)
		return float4(1, 1, 1, 0);

	// Convert position to world space
	float4 position = CalculateWorldPosition(input.TexCoord, depthVal);

	// Calculate light color
	float4 lightOutput = DirectionalLightPS(input, position);
	
	// Calculate shadow
	float3 shadow = FindShadow(depthVal, position);

	lightOutput.rgb *= shadow;
	return lightOutput;
}

half4 PixelShift(VertexShaderOutput input) : COLOR0
{	
	float2 stippleOffset;
	stippleOffset.x = 0;
	stippleOffset.y = frac(input.TexCoord.y * 360);
	float step = 0;

	// Shift the odd row pixels left
	float horizontalStep = 1.0 / 1280.0f;
	input.TexCoord.x += horizontalStep * round(stippleOffset.y);

	float4 position = (float4)0;

	return DirectionalLightPS(input, position);
}

technique NoShadow
{
    pass Pass1
    {
        VertexShader = compile vs_3_0 VertexShaderFunction();
        PixelShader = compile ps_3_0 PixelShaderFunction();
    }
}

technique Shadowed
{
    pass Pass1
    {
        VertexShader = compile vs_3_0 VertexShaderFunction();
        PixelShader = compile ps_3_0 PixelShaderShadowed();
    }
}