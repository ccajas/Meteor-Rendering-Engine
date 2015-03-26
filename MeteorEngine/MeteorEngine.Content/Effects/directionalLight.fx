
#define shadowBatchSize 12
 
float4x4 View;
float4x4 Projection;
float4x4 lightViewProj[shadowBatchSize];
float4x4 inverseView;
float4x4 invertViewProj;
 
float2 halfPixel;
float2 mapOffset[shadowBatchSize];
float3 camPosition;
 
float3 lightDirection;
float3 lightColor;
float lightIntensity;
float shadowLoops;
 
texture depthMap;
texture normalMap;
texture shadowMap, shadowViewMap;
texture positionMap;
 
float shadowBrightness;
const float ambient;
const float shadowMapSize;
const float2 shadowMapPixelSize;
 
sampler normalSampler : register(s1) = sampler_state
{
 	Filter = MIN_MAG_MIP_LINEAR;
 	AddressU = Wrap;
 	AddressV = Wrap;
 	Texture = <normalMap>;
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
 	MinFilter = POINT;
 	MagFilter = POINT;
 	MipFilter = NONE;
 	AddressU = Clamp;
 	AddressV = Clamp;
 	Texture = <shadowMap>;
};
 
sampler positionSampler = sampler_state
{
 	MinFilter = POINT;
 	MagFilter = POINT;
 	MipFilter = NONE;
 	AddressU = Clamp;
 	AddressV = Clamp;
 	Texture = <positionMap>;
};
 
sampler shadowViewSampler = sampler_state
{
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = NONE;
	AddressU = Clamp;
	AddressV = Clamp;
	Texture = <shadowViewMap>;
};

struct VertexShaderInput
{
    float4 Position : POSITION0;
 	float2 TexCoord : TEXCOORD0;
};
 
struct VertexShaderOutput
{
    float4 Position : POSITION0;
 	float2 TexCoord : TEXCOORD0;
};
 
struct VertexOutputViewMatrix
{
    float4 Position : POSITION0;
 	float2 TexCoord : TEXCOORD0;
 	float4x4 lightViewProj : TEXCOORD1;
};
 
struct InstanceInput
{
 	float4 vWorld1 : TEXCOORD1;
 	float4 vWorld2 : TEXCOORD2;
 	float4 vWorld3 : TEXCOORD3;
 	float4 vWorld4 : TEXCOORD4;
};
 
VertexShaderOutput VertexShaderFunction(VertexShaderInput input)
{
	VertexShaderOutput output;
 
	output.Position = input.Position;
	output.TexCoord = input.TexCoord + halfPixel;
 
	return output;
}
 
VertexOutputViewMatrix VertexShaderInstanced(
 	VertexShaderInput input, InstanceInput instance)
{
    VertexOutputViewMatrix output;
 
    output.Position = input.Position;
 	output.TexCoord = input.TexCoord + halfPixel;
 
 	float4x4 worldInstance = 
 		float4x4(instance.vWorld1, instance.vWorld2, instance.vWorld3, instance.vWorld4);
 
 	output.lightViewProj = worldInstance;
 	//output.Position = mul(input.Position, worldInstance);
 
    return output;
}
 
float DepthBias = 0.0005f;
 
 // Linear filter with 4 samples
 // Source by XNA Info
 // http://www.xnainfo.com/content.php?content=36
 
float LinearFilter4Samples(sampler smp, float2 texCoord, float ourdepth)
{	
 	// Get the current depth stored in the shadow map
 	float4x4 samples = (float4x4)0; 
 	float4 newSamples;
 
 	//for (int i = 0; i < 2; i++)
 	//{
 		samples[0].x = tex2Dgrad(smp, texCoord + float2(0%2,     0/2) * shadowMapPixelSize, 0, 0).r > ourdepth;
 		samples[0].y = tex2Dgrad(smp, texCoord + float2(0%2 + 1, 0/2) * shadowMapPixelSize, 0, 0).r > ourdepth;
 		samples[0].z = tex2Dgrad(smp, texCoord + float2(0%2,     0/2 + 1) * shadowMapPixelSize, 0, 0).r > ourdepth;
 		samples[0].w = tex2Dgrad(smp, texCoord + float2(0%2 + 1, 0/2 + 1) * shadowMapPixelSize, 0, 0).r > ourdepth;
 
 		//newSamples[i] = (samples[i].x + samples[i].y + samples[i].z + samples[i].w) / 4.0f;  
 	//} 
 
	half shadow = tex2D(smp, texCoord).r > ourdepth;
	//float shadow = dot(samples[0], 0.25f);
 		
 	// Determine the lerp amounts           
	//float2 lerps = frac(texCoord * shadowMapSize);
 
 	// lerp between the shadow values to calculate our light amount
	//float shadow = lerp(lerp(samples[0].x, samples[0].y, lerps.x), 
	//	lerp(samples[0].z, samples[0].w, lerps.x ), lerps.y); 
 	//float shadow = lerp(lerp(newSamples.x, newSamples.y, lerps.x), 
 	//	lerp(newSamples.z, newSamples.w, lerps.x ), lerps.y); 	
 	
 	return shadow;
}
 
float4 DirectionalLightPS(VertexShaderOutput input, float4 position) : COLOR0
{
 	float4 normalData = tex2D(normalSampler, input.TexCoord);
 	float3 normal = mul((2.0f * normalData.xyz - 1.0f), inverseView);
 
 	// Get specular data

	float specPower = 10;//normalData.a * 255;
	float specIntensity = 1;//normalData.a;
 
 	float3 lightDir = -normalize(lightDirection);
 
 	// Shadow data
 
	float4 shadow = tex2D(shadowViewSampler, input.TexCoord);
 	shadow = 1 - saturate(shadow - shadowBrightness);
 
 	// Reflection data
 
 	//float selfShadow = saturate(dot(lightDir, normal));
 	float3 reflection = normalize(reflect(-lightDir, normal)); 
 	float3 directionToCamera = normalize(camPosition - position);
 
 	// Compute the final specular factor
 	// Compute diffuse light
 	
 	float ndl = max(0, dot(normal, lightDir));
 	ndl = ambient + (ndl * (1 - ambient));
 	float3 diffuse = ndl * lightColor;
 

 	float specLight = specIntensity * 
 		pow(saturate(dot(directionToCamera, reflection)), specPower);
 
 	return float4(diffuse * lightIntensity * shadow, specLight);
}
 
float4 CalculateWorldPosition(float depthVal, float2 texCoord)
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
 	[branch]
 	if (depthVal > 0.9999f)
 		return float4(0.5, 0.5, 0.5, 0.15);
 
 	float4 position = tex2D(positionSampler, input.TexCoord);
 
 	return DirectionalLightPS(input, position);
}
 
float4 PixelShaderPosition(VertexShaderOutput input) : COLOR0
{
 	float depthVal = tex2D(depthSampler, input.TexCoord).r;
 	[branch]
 	if (depthVal > 0.9999f)
 		return float4(0.5, 0.5, 0.5, 0.15);
 
 	return CalculateWorldPosition(input.TexCoord, depthVal);
}
 
float4 PixelShaderShadowed(VertexOutputViewMatrix input) : COLOR0
{
 	float depthVal = tex2D(depthSampler, input.TexCoord).r;
 	float4 position = CalculateWorldPosition(depthVal, input.TexCoord);
 
 	if (depthVal > 0.9999f)
 		return 0;
 
 	// Shadow calculation
	float shadow = 0;
 	float shadowdepth = 0;
 		
 	[unroll(shadowBatchSize)]
 	for (float i = 0; i < shadowLoops; i++)
 	{
 		// Get shadow map position projected in light view
 		float4 shadowMapPos = mul(position, lightViewProj[i]);
 
 		// Find the position in the shadow map for this pixel
 		float2 shadowTexCoord = shadowMapPos.xy / shadowMapPos.w / 2.0f + float2(0.5, 0.5);
 		shadowTexCoord.y = 1 - shadowTexCoord.y;
 			
 		float4 comp = 0;
 		comp.x = shadowTexCoord.x <= 1;
 		comp.y = shadowTexCoord.y <= 1;
 		comp.z = shadowTexCoord.x >= 0;
 		comp.w = shadowTexCoord.y >= 0;
 		
		//[branch]
 		if (dot(comp, 1) == 4)
 		{
 			// Calculate the current pixel depth
 			float ourdepth = (shadowMapPos.z / shadowMapPos.w) - DepthBias;  
 
 			shadowTexCoord /= 8.f;
 			shadowTexCoord += mapOffset[i];
 
 			// Get the current depth stored in the shadow map
 			shadow += 1 - LinearFilter4Samples(shadowMapSampler, shadowTexCoord, ourdepth);		
		}	
 	}
 
 	return shadow;
 }
 
 technique CalculatePosition
 {
     pass Pass1
     {
         VertexShader = compile vs_3_0 VertexShaderFunction();
         PixelShader = compile ps_3_0 PixelShaderPosition();
     }
 }
 
 technique DrawFinal
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
