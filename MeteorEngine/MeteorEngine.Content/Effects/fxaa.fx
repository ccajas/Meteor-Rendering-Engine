//-----------------------------------------
//	FXAA
//-----------------------------------------

float4x4 World;
float4x4 View;
float4x4 Projection;

const float2 halfPixel;
texture Texture;

sampler texSampler = sampler_state
{
	Filter = MIN_MAG_MIP_LINEAR;
	AddressU = Clamp;
	AddressV = Clamp;
	Texture = <Texture>;
};

struct VertexShaderInput
{
    float3 Position : POSITION0;
	float2 TexCoord : TEXCOORD0;
};

struct VertexShaderOutput
{
    float4 Position : POSITION0;
	float2 TexCoord : TEXCOORD0;
	float4 ScreenPos : TEXCOORD1;
};

VertexShaderOutput VertexShaderFunction(VertexShaderInput input)
{
    VertexShaderOutput output;

	// Just pass these through
    output.Position = float4(input.Position, 1);
	output.ScreenPos = output.Position;
	output.TexCoord = input.TexCoord - halfPixel;

    return output;
}

/*!
 * Original FXAA algorithm by Timothy Lottes
 * <http://timothylottes.blogspot.com/2011/06/fxaa3-source-released.html>
 */

uniform float FXAA_SPAN_MAX = 8.0;
uniform float FXAA_REDUCE_MIN = 1.0/128.0f;
uniform float FXAA_REDUCE_MUL = 1.0/8.0;
							  
#define FxaaInt2 float2
#define FxaaFloat2 float2
#define FxaaTexLod(t, p) tex2Dlod(t, float4(p, 0.0, 0.0))
#define FxaaTexOff(t, p, o, r) tex2Dlod(t, float4(p + (o * r), 0, 0))

const float2 rcpFrame = float2(1 / 1280.f, 1 / 720.f);
							  
float4 FxaaPixelShader(VertexShaderOutput input) : COLOR0 
{
	// Obtain screen position
	input.ScreenPos.xy /= input.ScreenPos.w;

	// Output of FxaaVertexShader interpolated across screen.

	sampler2D tex = texSampler; // Input texture.
	float4 posPos = input.ScreenPos;
	posPos.xy = 0.5 * (float2(input.ScreenPos.x, -input.ScreenPos.y) + 1);
	posPos.y += halfPixel.y;

	float alpha = FxaaTexLod (tex, posPos.xy).a;

    float3 rgbNW = FxaaTexLod (tex, posPos.xy).xyz;
    float3 rgbNE = FxaaTexOff (tex, posPos.xy, float2(1,0), rcpFrame.xy).xyz;
    float3 rgbSW = FxaaTexOff (tex, posPos.xy, float2(0,1), rcpFrame.xy).xyz;
    float3 rgbSE = FxaaTexOff (tex, posPos.xy, float2(1,1), rcpFrame.xy).xyz;
    float3 rgbM  = FxaaTexLod (tex, posPos.xy).xyz;

    float3 luma = float3(0.299, 0.587, 0.114);
    float lumaNW = dot(rgbNW, luma);
    float lumaNE = dot(rgbNE, luma);
    float lumaSW = dot(rgbSW, luma);
    float lumaSE = dot(rgbSE, luma);
    float lumaM  = dot(rgbM,  luma);

    float lumaMin = min(lumaM, min(min(lumaNW, lumaNE), min(lumaSW, lumaSE)));
    float lumaMax = max(lumaM, max(max(lumaNW, lumaNE), max(lumaSW, lumaSE)));

    float2 dir;
    dir.x = -((lumaNW + lumaNE) - (lumaSW + lumaSE));
    dir.y =  ((lumaNW + lumaSW) - (lumaNE + lumaSE));

    float dirReduce = max(
		(lumaNW + lumaNE + lumaSW + lumaSE) * (0.25 * FXAA_REDUCE_MUL), FXAA_REDUCE_MIN);
    float rcpDirMin = 1.0/(min(abs(dir.x), abs(dir.y)) + dirReduce);
    dir = min(FxaaFloat2(FXAA_SPAN_MAX, FXAA_SPAN_MAX),
			  max(FxaaFloat2(-FXAA_SPAN_MAX, -FXAA_SPAN_MAX), dir * rcpDirMin)) * rcpFrame.xy;

    float3 rgbA = (1.0/2.0) * 
		(FxaaTexLod (tex, posPos.xy + dir * (1.0/3.0 - 0.5)).xyz +
		FxaaTexLod (tex, posPos.xy + dir * (2.0/3.0 - 0.5)).xyz);
    float3 rgbB = rgbA * (1.0/2.0) + (1.0/4.0) * 
		(FxaaTexLod (tex, posPos.xy + dir * (0.0/3.0 - 0.5)).xyz +
		FxaaTexLod (tex, posPos.xy + dir * (3.0/3.0 - 0.5)).xyz);

    float lumaB = dot(rgbB, luma);
    if((lumaB < lumaMin) || (lumaB > lumaMax)) 
		return saturate(float4 (rgbA, alpha));

	return saturate(float4 (rgbB, alpha)); 
}

float lumRGB(float3 color)
{
    return dot(color, float3(0.299, 0.587, 0.114));
}

float4 SmallFxaaPixelShader(VertexShaderOutput input) : COLOR0
{
    float2 UV = input.TexCoord.xy += halfPixel;// * rcpFrame;
	
    float w = 2.75;
	
    float t = lumRGB(tex2D(texSampler, UV + float2(0.0, -1.0) * w * rcpFrame).xyz);
	float l = lumRGB(tex2D(texSampler, UV + float2(-1.0, 0.0) * w * rcpFrame).xyz);
	float r = lumRGB(tex2D(texSampler, UV + float2(1.0, 0.0) * w * rcpFrame).xyz);
	float b = lumRGB(tex2D(texSampler, UV + float2(0.0, 1.0) * w * rcpFrame).xyz);
	
    float2 n = float2(-(t - b), r - l);
    float nl = length(n);
	
    if (nl < (1.0 / 16.0))
		return tex2D(texSampler, UV);

	n *= rcpFrame / nl;
		
	float4 o = tex2D(texSampler, UV);
	float4 t0 = tex2D(texSampler, UV + n) * 0.9;
	float4 t1 = tex2D(texSampler, UV - n) * 0.9;
	float4 t2 = tex2D(texSampler, UV + n) * 0.75;
	float4 t3 = tex2D(texSampler, UV - n) * 0.75;
		
	return (o + t0 + t1 + t2 + t3) / 4.25f;
}

technique Technique1
{
    pass Pass1
    {
        VertexShader = compile vs_3_0 VertexShaderFunction();
        PixelShader = compile ps_3_0 FxaaPixelShader();
    }
}
