//-----------------------------------------------------------------------------
// ReconstructDepth.fx
//
// Jorge Adriano Luna 2011
// http://jcoluna.wordpress.com
//-----------------------------------------------------------------------------


//-----------------------------------------
// Parameters
//-----------------------------------------
float FarClip;
float2 GBufferPixelSize;
float2 ProjectionValues;
	
//-----------------------------------------
// Textures
//-----------------------------------------
texture DepthBuffer;
sampler2D depthSampler = sampler_state
{
	Texture = <DepthBuffer>;
	MipFilter = NONE;
	MagFilter = POINT;
	MinFilter = POINT;
	AddressU = Clamp;
	AddressV = Clamp;
};


struct VertexShaderInput
{
    float4 Position : POSITION0;
};

struct VertexShaderOutput
{
    float4 Position : POSITION0;
	float2 TexCoord : TEXCOORD0;
};

VertexShaderOutput VertexShaderFunction(VertexShaderInput input)
{
    
    VertexShaderOutput output = (VertexShaderOutput)0;
	
	output.Position = input.Position;
	output.TexCoord = input.Position.xy * 0.5f + float2(0.5f,0.5f); 
	output.TexCoord.y = 1 - output.TexCoord.y;	
	output.TexCoord += GBufferPixelSize;

	return output;
}


struct PixelShaderOutput
{
	float4 Color :COLOR0;
	float Depth :DEPTH0;
};

PixelShaderOutput PixelShaderFunction(VertexShaderOutput input) 
{   
	PixelShaderOutput output = (PixelShaderOutput)0;

	//read the depth value
	float depthValue = - tex2D(depthSampler, input.TexCoord).r * FarClip;
	
	//we could do zw = mul(float4(0, 0, depthValue, 1), Projection).zw , and Z = zw.x/zw.y
	//but our projection transform is made of almost only 0s. Lets optimize it a bit.
	
	float z = ProjectionValues.x * depthValue + ProjectionValues.y;
	output.Depth = -z/depthValue;
	
    return output;
}

technique ReconstructDepth
{
    pass ReconstructDepthPass
    {
        VertexShader = compile vs_2_0 VertexShaderFunction();
        PixelShader = compile ps_2_0 PixelShaderFunction();
    }
}
