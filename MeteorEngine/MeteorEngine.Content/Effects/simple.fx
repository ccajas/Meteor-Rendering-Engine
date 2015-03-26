/// Very basic shader ahead

float4x4 World;
float4x4 View;
float4x4 Projection;

texture DiffuseMap;

sampler diffuseSampler = sampler_state
{
    Texture = <DiffuseMap>;
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Wrap;
    AddressV = Wrap;
};

float2 halfPixel;

struct VertexShaderBasicOutput
{
    float4 Position : POSITION0;
	float2 TexCoord : TEXCOORD0;
};

VertexShaderBasicOutput BasicVS(
	float3 position : POSITION0, float2 texCoord : TEXCOORD0)
{
    VertexShaderBasicOutput output;
	float4x4 wvp = mul(mul(World, View), Projection);

	// Just pass these through
    output.Position = mul(float4(position, 1), wvp);
	output.TexCoord = texCoord;// + halfPixel;

    return output;
}

float4 BasicPS(VertexShaderBasicOutput input) : COLOR0
{
    // Simply return the input texture color
	return tex2D(diffuseSampler, input.TexCoord);
}

technique PassThrough
{
    pass Pass1
    {
		CullMode = None;
		ZENABLE = True;
		ZFUNC = LESSEQUAL;
		ZWRITEENABLE = False;		

        VertexShader = compile vs_2_0 BasicVS();
        PixelShader = compile ps_2_0 BasicPS();
    }
}