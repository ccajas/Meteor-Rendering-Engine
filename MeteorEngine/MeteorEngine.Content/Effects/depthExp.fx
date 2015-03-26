float4x4 World;
float4x4 View;
float4x4 Projection;

float3 LightPosition;

//This is for modulating the Light's Depth Precision
float DepthPrecision;

//Input Structure
struct VSIn	
{
	float4 Position : POSITION0;
};

//Output Structure
struct VSOut
{
	float4 Position : POSITION0;
	float4 WorldPosition : TEXCOORD0;
};

//Vertex Shader
VSOut VertexShaderFunction(VSIn input)
{
	//Initialize Output
	VSOut output;

	//Transform Position
	float4 worldPosition = mul(input.Position, World);
	float4 viewPosition = mul(worldPosition, View);
	output.Position = mul(viewPosition, Projection);

	//Pass World Position
	output.WorldPosition = worldPosition;

	//Return Output
	return output;
}

#define MaxBones 58
float4x4 bones[MaxBones];

//Pixel Shader
float4 PixelShaderFunction(VSOut input) : COLOR0
{
	//Fix World Position
	input.WorldPosition /= input.WorldPosition.w;

	//Calculate Depth from Light
	float depth = max(0.01f, length(LightPosition - input.WorldPosition)) / DepthPrecision;

	//Return Exponential of Depth
	return exp((DepthPrecision * 0.5f) * depth);
}

//Technique

technique Default
{
    pass Pass1
    {
        // TODO: set renderstates here.

        VertexShader = compile vs_3_0 VertexShaderFunction();
        PixelShader = compile ps_3_0 PixelShaderFunction();
    }
}

technique DefaultAnimated
{
    pass Pass1
    {
        // TODO: set renderstates here.

        VertexShader = compile vs_3_0 VertexShaderFunction();
        PixelShader = compile ps_3_0 PixelShaderFunction();
    }
}
