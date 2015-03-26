
struct VertexShaderInput
{
    float3 Position : POSITION0;
};

float4 VertexShaderFunction(VertexShaderInput input) : POSITION0
{
    float4 Position = float4(input.Position, 1);
    return Position;
}

struct PixelShaderOutput1
{
    half4 Color : COLOR0;
    half4 Normal : COLOR1;
    half4 Depth : COLOR2;
};

struct PixelShaderOutput2
{
    half4 Normal : COLOR0;
    half4 Depth : COLOR1;
};

PixelShaderOutput1 PixelShaderClearGBuffer()
{
    PixelShaderOutput1 output;

    //black color
    output.Color = 0.0f;
	output.Color.a = 0.0f;

    //when transforming 0.5f into [-1,1], we will get 0.0f
    output.Normal.rgb = 0.5f;

    //no specular power
    output.Normal.a = 0.0f;

    //max depth
    output.Depth = 1.0f;
    return output;
}

PixelShaderOutput2 PixelShaderClearSmallGBuffer()
{
    PixelShaderOutput2 output;

    //when transforming 0.5f into [-1,1], we will get 0.0f
    output.Normal.rgb = 0.5f;

    //no specular power
    output.Normal.a = 0.0f;

    //max depth
    output.Depth = 1.0f;
    return output;
}

technique Clear
{
    pass Pass1
    {
        VertexShader = compile vs_2_0 VertexShaderFunction();
        PixelShader = compile ps_2_0 PixelShaderClearGBuffer();
    }
}

technique ClearSmall
{
    pass Pass1
    {
        VertexShader = compile vs_2_0 VertexShaderFunction();
        PixelShader = compile ps_2_0 PixelShaderClearSmallGBuffer();
    }
}