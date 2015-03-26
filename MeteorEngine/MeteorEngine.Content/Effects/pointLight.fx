
float4x4 World;
float4x4 View;
float4x4 Projection;

float4x4 inverseView;
float4x4 inverseProjection;
float4x4 invertViewProj;

float2 halfPixel;
float3 viewPosition;
float3 lightPosition;
float lightIntensity;
float lightRadius;
float3 Color;

texture depthMap;
texture normalMap;

sampler normalSampler :		register(s1) = sampler_state
{
	Filter = MIN_MAG_MIP_LINEAR;
	AddressU = Clamp;
	AddressV = Clamp;
	Texture = <normalMap>;
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

float4 LightingFunction(VertexShaderOutput input, half2 texCoord) : COLOR0
{	
	// Get normal data

	float4 normalData = tex2D (normalSampler, texCoord);
	float3 normal = mul((2.0f * normalData.xyz - 1.0f), inverseView);
	
	// Get depth data

	float depthVal = tex2D(depthSampler, texCoord).r;

	// Get specular data

	float specPower = 10;//normalData.a * 255;
	float specIntensity = 1;//normalData.a;

	// Compute screen-space position

	float4 position;
	position.xy = input.ScreenPos.xy;
	position.z = depthVal;
	position.w = 1.0f;

	position = mul(position, invertViewProj);
	position /= position.w;

	// Surface-to-light vector

	float lightRadius = input.radius;	

	// calculate distance to light in world space
	float3 L = input.lightPos - position;
	float3 lightDir = input.lightPos - position;

	float attenuation = saturate(1 - dot(L / lightRadius, L / lightRadius));

	lightDir = normalize(lightDir);

	// Reflection data
	
	float3 reflection = normalize(reflect(-lightDir, normal));

	// Compute the final specular factor

	float specLight = specIntensity * pow(dot(reflection, lightDir), specPower);

	// Compute diffuse light

	float ndl = saturate(dot(normal, lightDir));
	float3 diffuse = ndl * input.Color.rgb;

	float4 output = attenuation * lightIntensity * float4(diffuse, specLight);

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
