//-----------------------------------------
//	TerrainDepth
//-----------------------------------------

float4x4 World;
float4x4 LightViewProj;

/// Visual texture features

float textureScale;
float mapScale;
float heightScale;
float meshSize;
float specPower;
float specIntensity;
float bumpIntensity;

/// Debug features

float clipLevel;

/// Base textures

texture Texture;

//--- Structures ---

struct VertexShaderInput
{
    float4 position : POSITION;
};

struct VertexShaderOutput
{
	float4 position : POSITION;
	float depth : TEXCOORD1;
};

//--- VertexShader ---

VertexShaderOutput DepthMapVS(VertexShaderInput input)
{
	VertexShaderOutput output;

	float4x4 wvp = mul(World, LightViewProj);

	float4 localPosition;
	localPosition.x = input.position.x % meshSize;
	localPosition.y = input.position.y * heightScale;
	localPosition.z = -(int)(input.position.x / meshSize);
	localPosition.w = 1;

	output.position = mul(localPosition, wvp);
	output.depth = output.position.z;
	
	return output;
}

//--- PixelShader ---

float4 DepthMapPS (VertexShaderOutput IN) : COLOR0
{	
    return IN.depth;
}

//--- Techniques ---

technique Default
{
    pass P0
    {
		ZEnable = true;
		CullMode = CCW;
        VertexShader = compile vs_3_0 DepthMapVS();
        PixelShader = compile ps_3_0 DepthMapPS();
    }
}
