float DepthBias = 0.0002f;

/// Poisson disk samples used for shadow filtering

float2 poissonDisk[24] = { 
	float2(0.5713538f, 0.7814451f),
	float2(0.2306823f, 0.6228884f),
	float2(0.1000122f, 0.9680607f),
	float2(0.947788f, 0.2773731f),
	float2(0.2837818f, 0.303393f),
	float2(0.6001099f, 0.4147638f),
	float2(-0.2314563f, 0.5434746f),
	float2(-0.08173513f, 0.0796717f),
	float2(-0.4692954f, 0.8651238f),
	float2(0.2768489f, -0.3682062f),
	float2(-0.5900795f, 0.3607553f),
	float2(-0.1010569f, -0.5284956f),
	float2(-0.4741178f, -0.2713854f),
	float2(0.4067073f, -0.00782522f),
	float2(-0.4603044f, 0.0511527f),
	float2(0.9820454f, -0.1295522f),
	float2(0.8187376f, -0.4105208f),
	float2(-0.8115796f, -0.106716f),
	float2(-0.4698426f, -0.6179109f),
	float2(-0.8402727f, -0.4400948f),
	float2(-0.2302377f, -0.879307f),
	float2(0.2748472f, -0.708988f),
	float2(-0.7874522f, 0.6162704f),
	float2(-0.9310728f, 0.3289311f)
};

#define TOTAL_SAMPLES 20

float3 PoissonDiscFilter(sampler smp, float3 ambient, float2 texCoord, float ourdepth)
{	
	// Get the current depth stored in the shadow map
	float4 samples[TOTAL_SAMPLES]; 

	float shadow = 0;
	float sampleDiscSize = 1.7f;
	float2 pixelSize = shadowMapPixelSize * sampleDiscSize;

	// Sample the texture at various offsets

	[unroll]
	for (int i = 0; i < TOTAL_SAMPLES; i++)
	{
		samples[i] = tex2D(smp, texCoord + poissonDisk[i] * pixelSize).r > ourdepth;
		shadow += samples[i];
	}

	shadow /= (TOTAL_SAMPLES + 1);
	return shadow + ambientTerm;// * 3;
}

float3 FindCascadeShadow(float4 shadowMapPos, float shadowIndex)
{
	// In progress: calculate the bias based on the angle of the surface relative to the light
	//float3 lightDir = -normalize(lightDirection);
	//float bias = dot(lightDir, normal) * 0.005f;

	// Project the shadow map and find the position in it for this pixel
	float2 shadowTexCoord = shadowMapPos.xy / shadowMapPos.w / 2.0f + float2(0.5, 0.5);

	shadowTexCoord.y = 1 - shadowTexCoord.y;
	shadowTexCoord += float2(shadowIndex % MAPS_PER_ROW, floor(shadowIndex / MAPS_PER_ROW));
	shadowTexCoord /= float2(MAPS_PER_ROW, MAPS_PER_COL);

	// Calculate the current pixel depth
	float ourdepth = (shadowMapPos.z / shadowMapPos.w) - DepthBias;  

	// Shadow calculation
	float3 shadow = 
		PoissonDiscFilter(shadowMapSampler, ambientTerm, shadowTexCoord, ourdepth);
	return shadow;
}

float3 FindShadow(float depthVal, float4 position)
{
	// Get linear depth space from viewport distance
	float camNear = 0.0008f;
	float camFar = 1.f;
	float linearZ = (2 * camNear) / (camFar + camNear - depthVal * (camFar - camNear));

	// Get the light projection for the first available frustum split	
	float shadowIndex = 0;
	float extend = 1.5f;

	[unroll]
	for (int i = 0; i < NUM_CASCADES; i++)  
		shadowIndex += (linearZ > cascadeSplits[i] * extend);

	// Get shadow map position projected in light view
	float4 shadowMapPos = mul(position, lightViewProj[shadowIndex]);

	// Find the position in the shadow map for this pixel
	float3 shadow = FindCascadeShadow(shadowMapPos, shadowIndex);

	// Calculates minimum cascade distance to start blending in shadow
	// from the next cascade for a smoother transition. This reduces the
	// 'pop' or seam visible where the cascades are split.
	float minDistance = cascadeSplits[shadowIndex] * 0.8f * extend;
	
	if (linearZ > minDistance)
	{
		// Get second shadow map position projected in light view
		float4 shadowMapPos2 = mul(position, lightViewProj[shadowIndex + 1]);
		float relDistance = (linearZ - minDistance) / (cascadeSplits[shadowIndex] * 
			extend - minDistance);

		// Get shadow value from next cascade and blend the results
		float3 shadow2 = FindCascadeShadow(shadowMapPos2, shadowIndex + 1);

		shadow = lerp(shadow, shadow2, relDistance);
	}

	return shadow;
}