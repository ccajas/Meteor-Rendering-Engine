
float4x4 World;
float4x4 View;
float4x4 Projection;

float3 camPosition;
float specularIntensity = 1.0f;
float specularPower = 0.2f; 

texture Texture;
texture normalMap;

sampler diffuseSampler = sampler_state
{
    Texture = (Texture);
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Wrap;
    AddressV = Wrap;
};

sampler normalSampler = sampler_state
{
    Texture = (normalMap);
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Wrap;
    AddressV = Wrap;
};

struct VertexShaderInput
{
    float4 Position : POSITION0;
    float3 Normal : NORMAL0;
    float2 TexCoord : TEXCOORD0;
};

struct VertexShaderOutput
{
    float4 Position : POSITION0;
    float2 TexCoord : TEXCOORD0;
    float3 Normal : TEXCOORD1;
    float2 Depth : TEXCOORD2;
};

VertexShaderOutput VertexShaderFunction(VertexShaderInput input)
{
    VertexShaderOutput output;

    float4 worldPosition = mul(input.Position, World);
    float4 viewPosition = mul(worldPosition, View);
    output.Position = mul(viewPosition, Projection);

	//pass the texture coordinates further
    output.TexCoord = input.TexCoord;

	//get normal into world space
    output.Normal = mul(input.Normal, World);
    output.Depth.x = output.Position.z;
    output.Depth.y = output.Position.w;

    return output;
}

half4 PS_ColorTarget(VertexShaderOutput input) : COLOR0
{
	half4 color;

	//output Color
    color = tex2D(diffuseSampler, input.TexCoord);

	//output SpecularIntensity
    color.a = specularIntensity; 
    return color;
}

half4 PS_NormalTarget(VertexShaderOutput input) : COLOR0
{
	half4 normal;

	//transform normal domain
	float3 screenNormal = normalize(input.Normal.xyz);
    normal.rgb = 0.5f * (screenNormal + 1.0f);

    float3 normalFromMap = tex2D(normalSampler, input.TexCoord);
	normal.rgb *= normalFromMap;//normal;

	//output SpecularPower
    normal.a = specularPower;
    return normal;
}

half4 PS_DepthTarget(VertexShaderOutput input) : COLOR0
{
	half4 depth;
	depth = input.Depth.x / input.Depth.y;   
    return depth;
}

technique ColorPass
{
    pass Pass1
    {
	    ZEnable = true;
        VertexShader = compile vs_2_0 VertexShaderFunction();
        PixelShader = compile ps_2_0 PS_ColorTarget();
    }
}

technique NormalPass
{
    pass Pass1
    {
	    ZEnable = true;
        VertexShader = compile vs_2_0 VertexShaderFunction();
        PixelShader = compile ps_2_0 PS_NormalTarget();
    }
}

technique DepthPass
{
    pass Pass1
    {
	    ZEnable = true;
        VertexShader = compile vs_2_0 VertexShaderFunction();
        PixelShader = compile ps_2_0 PS_DepthTarget();
    }
}