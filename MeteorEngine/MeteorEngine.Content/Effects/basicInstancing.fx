
// BasicInstancing.fx

// Camera settings
float4x4 World;
float4x4 View;
float4x4 Projection;

texture Texture;

sampler2D Sampler = sampler_state
{
    Filter = MIN_MAG_MIP_LINEAR;
    Texture = <Texture>;
};

struct VertexShaderInput
{
    float4 Position : POSITION0;
    float3 Normal : NORMAL0;
    float2 TextureCoordinate : TEXCOORD0;
};

struct InstanceInput
{
	float4 vWorld1 : TEXCOORD1;
	float4 vWorld2 : TEXCOORD2;
	float4 vWorld3 : TEXCOORD3;
	float4 vWorld4 : TEXCOORD4;
	float4 vColor : COLOR1;
};

struct VertexShaderOutput
{
    float4 Position : POSITION0;
    float4 Color : COLOR0;
    float2 TextureCoordinate : TEXCOORD0;
	float3 Normal : TEXCOORD1;
    float4 WorldPos : TEXCOORD2;
	float4 ShadowTexCoord : TEXCOORD3;
};

// Vertex shader helper function shared between the two techniques.
VertexShaderOutput VertexShaderCommon(VertexShaderInput input, InstanceInput instance)
{
    VertexShaderOutput output;

	float4x4 wvp = mul(mul(World, View), Projection);

	float4x4 WorldInstance = 
		float4x4(instance.vWorld1, instance.vWorld2, instance.vWorld3, instance.vWorld4);

    // Apply the world and camera matrices to compute the output position.
	input.Position = mul(input.Position, WorldInstance);
    output.Position = mul(input.Position, wvp);

    // Compute lighting, using a simple Lambert model.
    output.Normal = normalize(mul(input.Normal, WorldInstance));

    // Just pass these through
    output.TextureCoordinate = input.TextureCoordinate;
    output.Color = instance.vColor;

    return output;
}

// Hardware instancing reads the per-instance world transform from a 
// secondary vertex stream

VertexShaderOutput VS_HardwareInstancing(
	VertexShaderInput input, InstanceInput instanceTransform)
{
    return VertexShaderCommon(input, instanceTransform);
}

float4 PS_Shadowed(VertexShaderOutput input) : COLOR
{
	float4 tColor = tex2D(Sampler, input.TextureCoordinate);
	float3 vLight = normalize(lightDirection);

    float diffuseIntensity = saturate (dot(vLight, input.Normal) + 0.1);
    float4 diffuseColor = lightColor * diffuseIntensity;

	float3 reflect = normalize(5 * diffuseIntensity * input.Normal - vLight); 
	float4 totalSpec = pow(saturate(dot(reflect, vLight)), 200);
    
    // Find the position of this pixel in light space
    float4 lightingPosition = mul(input.WorldPos, lightViewProj);

	// PCF filtering go!
	float lightingFactor = PCFfilter(input.ShadowTexCoord, lightingPosition);
	lightingFactor = (lightingFactor > 0.85f) ? 1.0f : lightingFactor;

    // Shadow the pixel by lowering the intensity
    diffuseColor *= float4(lightingFactor, lightingFactor, lightingFactor, 1);
    
	input.Color.xyz *= diffuseColor + ambientColor + totalSpec * 10;
	return clamp(1, 0, input.Color * tColor);
}