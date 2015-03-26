//-----------------------------------------
//	PointLight
//-----------------------------------------

float4x4 World;
float4x4 View;
float4x4 Projection;

float4x4 inverseView;
float4x4 inverseProjection;
float4x4 invertViewProj;

float2 halfPixel;
float3 camPosition;
float3 lightPosition;
float lightIntensity;
float lightRadius;
float3 Color;

texture depthMap;
texture specularMap;
texture normalMap;

sampler normalSampler : register(s1) = sampler_state
{
	Filter = MIN_MAG_MIP_LINEAR;
	AddressU = Clamp;
	AddressV = Clamp;
	Texture = <normalMap>;
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

struct VertexShaderInput
{
    float3 Position : POSITION0;
};

struct VertexShaderOutput
{
    float4 Position : POSITION0;
	float4 ScreenPos : TEXCOORD0;
	float3 lightPos : TEXCOORD1;
	float radius : TEXCOORD2;
	float4 Color : COLOR0;
};

struct InstanceInput
{
	float4 vWorld1 : TEXCOORD1;
	float4 vWorld2 : TEXCOORD2;
	float4 vWorld3 : TEXCOORD3;
	float4 vWorld4 : TEXCOORD4;
	float4 vColor : COLOR1;
};

VertexShaderOutput VertexShaderFunction(
	VertexShaderInput input, InstanceInput instance)
{
    VertexShaderOutput output;

	float4x4 wvp = mul(View, Projection);
	float4x4 WorldInstance = 
		float4x4(instance.vWorld1, instance.vWorld2, instance.vWorld3, instance.vWorld4);

	// Apply the world and camera matrices to compute the output position.
	float4 worldPosition = mul(float4(input.Position, 1), WorldInstance);

	// Pass matrix translation and screen position

    output.Position = mul(worldPosition, wvp);
	output.ScreenPos = output.Position;
	output.lightPos = instance.vWorld4;

	// Compute the radius
	output.radius = length(float3(instance.vWorld1.xyz));
	output.Color = instance.vColor;

    return output;
}

// Blinn D1 (Phong) specular distribution 
float BlinnPhong(float3 normal, float3 view, float3 light, float specPower)
{					
	float3 halfVector = normalize(light + view);
	return pow(saturate(dot(normal, halfVector)), specPower * 4);
}

// Blinn D2 (Torrance-Sparrow/Gauss) specular distribution
float TorranceSparrow(float3 normal, float3 view, float3 light, float specPower) 
{
	float3 halfway = normalize(light + view);
	float normalDotHalfway = dot(normal, halfway);
	float alpha = acos(normalDotHalfway);
	return exp(-2 * specPower * pow(alpha, 2));
}

// Blinn D3 (Trowbridge-Reitz) specular distribution
float TrowbridgeReitz(float3 normal, float3 view, float3 light, float specPower)
{					
	float3 halfway = normalize(light + view);
	float normalDotHalfway = saturate(dot(normal, halfway));
	return pow(1 / (1 + (1 - pow(normalDotHalfway, 2)) * specPower), 2);
}

float4 LightingFunction(VertexShaderOutput input, half2 texCoord) : COLOR0
{	
	// Get normal data

	float4 normalData = tex2D (normalSampler, texCoord);
	float3 normal = mul((2.0f * normalData.xyz - 1.0f), inverseView);
	
	// Get depth data

	float depthVal = tex2D(depthSampler, texCoord).r;

	// Get specular data

	float4 specular = tex2D(specularSampler, texCoord);
	float specPower = specular.a * 255;
	float3 specIntensity = specular.rgb;

	// Compute screen-space position

	float4 position;
	position.xy = input.ScreenPos.xy;
	position.z = depthVal;
	position.w = 1.0f;

	position = mul(position, invertViewProj);
	position /= position.w;

	// Surface-to-light vector

	float lightRadius = input.radius;

	float3 lightDir = input.lightPos.xyz - position;
	float attenuation = saturate(1.0f - length(lightDir) / lightRadius);
	attenuation = pow(attenuation, 2);

	if (attenuation <= 0)
		return 0;

	lightDir = normalize(lightDir);

	// Reflection data
	
	float3 reflection = normalize(reflect(-lightDir, normal));
	float3 directionToCamera = normalize(camPosition - position);

	// Compute diffuse light

	float ndl = max(0, dot(normal, lightDir));
	float ndh = saturate(dot(reflection, lightDir));
	float3 diffuse = ndl * input.Color.rgb;

	// Compute the final specular factor

	float specLight = specIntensity * BlinnPhong(normal, directionToCamera, lightDir, specPower);
	//pow(saturate(dot(reflection, directionToCamera)), specPower);

	float4 output = float4(diffuse, specLight) * attenuation  * lightIntensity;
	return output;
}	

float4 PixelShaderFunction(VertexShaderOutput input) : COLOR0
{	
	// Obtain screen position
	input.ScreenPos.xy /= input.ScreenPos.w;

	// Obtain texture coords corresponding to the current pixel

	half2 texCoord = 0.5f * (float2(input.ScreenPos.x, - input.ScreenPos.y) + 1);
	texCoord += halfPixel;

	return LightingFunction(input, texCoord);
}

float4 PixelShaderFunction2(VertexShaderOutput input) : COLOR0
{	
	// Obtain screen position
	input.ScreenPos.xy /= input.ScreenPos.w;

	// Obtain texture coords corresponding to the current pixel

	half2 texCoord = 0.5f * (float2(input.ScreenPos.x, - input.ScreenPos.y) + 1);
	texCoord += halfPixel;

	half2 stippleOffset;
	stippleOffset.x = 0;// frac(texCoord.x * 640);
	stippleOffset.y = frac(texCoord.y * 360);

	// Shift the odd row pixels left
	float horizontalStep = 1.0 / 1280.0f;
	texCoord.x += horizontalStep * round(stippleOffset.y);

	return LightingFunction(input, texCoord);
}	

technique DefaultTechnique
{
    pass Pass0
    {
        VertexShader = compile vs_3_0 VertexShaderFunction();
        PixelShader = compile ps_3_0 PixelShaderFunction();
    }

    pass Pass1
    {
        VertexShader = compile vs_3_0 VertexShaderFunction();
        PixelShader = compile ps_3_0 PixelShaderFunction2();
    }
}
