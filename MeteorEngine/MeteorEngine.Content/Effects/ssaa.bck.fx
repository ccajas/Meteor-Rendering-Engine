float4x4 World;
float4x4 View;
float4x4 Projection;

const float2 halfPixel;
texture Texture;

// TODO: add effect parameters here.

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
	output.TexCoord = input.TexCoord + halfPixel;

    return output;
}

float GetColorLuminance( float3 i_vColor )
{    
	return dot(i_vColor, float3(0.2126f, 0.7152f, 0.0722f));
}

const float VIEWPORT_WIDTH = 1280.f;
const float VIEWPORT_HEIGHT = 720.f;

float4 PixelShaderFunction(VertexShaderOutput input) : COLOR0
{
	float2 i_TexCoord = input.TexCoord.xy;

	float2 vPixelViewport = float2( 1.0f / VIEWPORT_WIDTH, 1.0f / VIEWPORT_HEIGHT );

	// Normal, scale it up 3x for a better coverage area

	float2 upOffset = float2( 0, vPixelViewport.y ) * 2.f;
	float2 rightOffset = float2( vPixelViewport.x, 0 ) * 2.f;
	float topHeight = GetColorLuminance( tex2D( texSampler, i_TexCoord.xy+upOffset).rgb );
	float bottomHeight = GetColorLuminance( tex2D( texSampler, i_TexCoord.xy-upOffset).rgb );
	float rightHeight = GetColorLuminance( tex2D( texSampler, i_TexCoord.xy+rightOffset).rgb );
	float leftHeight = GetColorLuminance( tex2D( texSampler, i_TexCoord.xy-rightOffset).rgb );
	float leftTopHeight = GetColorLuminance( tex2D( texSampler, i_TexCoord.xy-rightOffset+upOffset).rgb );
	float leftBottomHeight = GetColorLuminance( tex2D( texSampler, i_TexCoord.xy-rightOffset-upOffset).rgb );
	float rightBottomHeight = GetColorLuminance( tex2D( texSampler, i_TexCoord.xy+rightOffset-upOffset).rgb );
	float rightTopHeight = GetColorLuminance( tex2D( texSampler, i_TexCoord.xy+rightOffset+upOffset).rgb );  
	
	// Normal map creation, this is where it differs.
	
	float sum0 = rightTopHeight + topHeight + rightBottomHeight;
	float sum1 = leftTopHeight + bottomHeight + leftBottomHeight;
	float sum2 = leftTopHeight + leftHeight + rightTopHeight;
	float sum3 = leftBottomHeight + rightHeight + rightBottomHeight;
	
	// Then for the final vectors, just subtract the opposite sample set.
	// The amount of "antialiasing" is directly related to "filterStrength".
	// Higher gives better AA, but too high causes artifacts.
	
	float filterStrength = 1.0f;
	float vec1 = (sum1 - sum0) * filterStrength;
	float vec2 = (sum2 - sum3) * filterStrength;
	
	// Put them together and multiply them by the offset scale for the final result.
	float2 Normal = float2( vec1, vec2);// clamp(float2( vec1, vec2), -float2(1, 1) * 0.4, float2(1, 1) * 0.4);
	// Color
	Normal.xy *= vPixelViewport;	
	// Increase pixel size to get more blur
	
	float3 Scene0 = tex2D(texSampler, i_TexCoord.xy );
	float3 Scene1 = tex2D(texSampler, i_TexCoord.xy + Normal.xy );
	float3 Scene2 = tex2D(texSampler, i_TexCoord.xy - Normal.xy );
	float3 Scene3 = tex2D(texSampler, i_TexCoord.xy + float2(Normal.x, -Normal.y) );
	float3 Scene4 = tex2D(texSampler, i_TexCoord.xy - float2(Normal.x, -Normal.y) );
	
	float alphaOut = tex2D(texSampler, input.TexCoord.xy).a;

	// Final color
	float4 color = float4(
		float3((Scene0 + Scene1 + Scene2 + Scene3 + Scene4) * 0.2), alphaOut);
	return saturate(color);
	
	// To debug the normal image, use this:
	return float4(normalize(float3(vec1, vec2, 1) * 0.5 + 0.5), 1);
	// using vec1 and vec2 for the debug output as Normal won't display anything (due to the pixel scale applied to it).
}

#define FXAA_PC 1
    #define int2 float2
    #define FxaaInt2 float2
    #define FxaaFloat2 float2
    #define FxaaFloat3 float3
    #define FxaaFloat4 float4
    #define FxaaDiscard clip(-1)
    #define FxaaDot3(a, b) dot(a, b)
    #define FxaaSat(x) saturate(x)
    #define FxaaLerp(x,y,s) lerp(x,y,s)
    #define FxaaTex sampler2D
    #define FxaaTexTop(t, p) tex2Dlod(t, float4(p, 0.0, 0.0))
    #define FxaaTexOff(t, p, o, r) tex2Dlod(t, float4(p + (o * r), 0, 0))

    //
    // The minimum amount of local contrast required to apply algorithm.
    //
    // 1/3 - too little
    // 1/4 - low quality
    // 1/6 - default
    // 1/8 - high quality
    // 1/16 - overkill
    //
    #define FXAA_QUALITY__EDGE_THRESHOLD (1.0/6.0)

    //
    // Trims the algorithm from processing darks.
    //
    // 1/32 - visible limit
    // 1/16 - high quality
    // 1/12 - upper limit (default, the start of visible unfiltered edges)
    //
    #define FXAA_QUALITY__EDGE_THRESHOLD_MIN (1.0/12.0)
    //
    // Choose the amount of sub-pixel aliasing removal.
    //
    // 1   - upper limit (softer)
    // 3/4 - default amount of filtering
    // 1/2 - lower limit (sharper, less sub-pixel aliasing removal)
    //
    //
    #define FXAA_QUALITY__SUBPIX (3.0/4.0)
/*============================================================================

                              FXAA3 QUALITY - PC

============================================================================*/
#if (FXAA_PC == 1)
/*--------------------------------------------------------------------------*/
float4 FxaaPixelShader(
    VertexShaderOutput input
) : COLOR0
{   
/*--------------------------------------------------------------------------*/
    float2 posM;
	float2 pos = 0.5f * (float2(input.ScreenPos.x, - input.ScreenPos.y) + 1);
    posM.x = pos.x;
    posM.y = pos.y;
	float2 rcpFrame = halfPixel * 2;

	sampler2D tex = texSampler;

    #if (FXAA_GATHER4_ALPHA == 1)
        #if (FXAA_DISCARD == 0)
            float4 rgbyM = FxaaTexTop(tex, posM);
            #define lumaM rgbyM.w
        #endif            
        float4 luma4A = FxaaTexAlpha4(tex, posM, rcpFrame.xy);
        float4 luma4B = FxaaTexOffAlpha4(tex, posM, FxaaInt2(-1, -1), rcpFrame.xy);
        #if (FXAA_DISCARD == 1)
            #define lumaM luma4A.w
        #endif
        #define lumaE luma4A.z
        #define lumaS luma4A.x
        #define lumaSE luma4A.y
        #define lumaNW luma4B.w
        #define lumaN luma4B.z
        #define lumaW luma4B.x
    #else
        float4 rgbyM = FxaaTexTop(tex, posM);
        #define lumaM rgbyM.w
        float lumaS = FxaaTexOff(tex, posM, FxaaInt2( 0, 1), rcpFrame.xy).w;
        float lumaE = FxaaTexOff(tex, posM, FxaaInt2( 1, 0), rcpFrame.xy).w;
        float lumaN = FxaaTexOff(tex, posM, FxaaInt2( 0,-1), rcpFrame.xy).w;
        float lumaW = FxaaTexOff(tex, posM, FxaaInt2(-1, 0), rcpFrame.xy).w;
    #endif
/*--------------------------------------------------------------------------*/
    float maxSM = max(lumaS, lumaM);
    float minSM = min(lumaS, lumaM);
    float maxESM = max(lumaE, maxSM); 
    float minESM = min(lumaE, minSM); 
    float maxWN = max(lumaN, lumaW);
    float minWN = min(lumaN, lumaW);
    float rangeMax = max(maxWN, maxESM);
    float rangeMin = min(minWN, minESM);
    float rangeMaxScaled = rangeMax * FXAA_QUALITY__EDGE_THRESHOLD;
    float range = rangeMax - rangeMin;
    float rangeMaxClamped = max(FXAA_QUALITY__EDGE_THRESHOLD_MIN, rangeMaxScaled);
    bool earlyExit = range < rangeMaxClamped;
/*--------------------------------------------------------------------------*/
    if(earlyExit) 
        #if (FXAA_DISCARD == 1)
            FxaaDiscard;
        #else
            return rgbyM;
        #endif
/*--------------------------------------------------------------------------*/
    #if (FXAA_GATHER4_ALPHA == 0) 
        float lumaNW = FxaaTexOff(tex, posM, FxaaInt2(-1,-1), rcpFrame.xy).w;
        float lumaSE = FxaaTexOff(tex, posM, FxaaInt2( 1, 1), rcpFrame.xy).w;
        float lumaNE = FxaaTexOff(tex, posM, FxaaInt2( 1,-1), rcpFrame.xy).w;
        float lumaSW = FxaaTexOff(tex, posM, FxaaInt2(-1, 1), rcpFrame.xy).w;
    #else
        float lumaNE = FxaaTexOff(tex, posM, FxaaInt2(1, -1), rcpFrame.xy).w;
        float lumaSW = FxaaTexOff(tex, posM, FxaaInt2(-1, 1), rcpFrame.xy).w;
    #endif
/*--------------------------------------------------------------------------*/
    float lumaNS = lumaN + lumaS;
    float lumaWE = lumaW + lumaE;
    float subpixRcpRange = 1.0/range;
    float subpixNSWE = lumaNS + lumaWE;
    float edgeHorz1 = (-2.0 * lumaM) + lumaNS;
    float edgeVert1 = (-2.0 * lumaM) + lumaWE;
/*--------------------------------------------------------------------------*/
    float lumaNESE = lumaNE + lumaSE;
    float lumaNWNE = lumaNW + lumaNE;
    float edgeHorz2 = (-2.0 * lumaE) + lumaNESE;
    float edgeVert2 = (-2.0 * lumaN) + lumaNWNE;
/*--------------------------------------------------------------------------*/
    float lumaNWSW = lumaNW + lumaSW;
    float lumaSWSE = lumaSW + lumaSE;
    float edgeHorz4 = (abs(edgeHorz1) * 2.0) + abs(edgeHorz2);
    float edgeVert4 = (abs(edgeVert1) * 2.0) + abs(edgeVert2);
    float edgeHorz3 = (-2.0 * lumaW) + lumaNWSW;
    float edgeVert3 = (-2.0 * lumaS) + lumaSWSE;
    float edgeHorz = abs(edgeHorz3) + edgeHorz4;
    float edgeVert = abs(edgeVert3) + edgeVert4;
/*--------------------------------------------------------------------------*/
    float subpixNWSWNESE = lumaNWSW + lumaNESE; 
    float lengthSign = rcpFrame.x;
    bool horzSpan = edgeHorz >= edgeVert;
    float subpixA = subpixNSWE * 2.0 + subpixNWSWNESE; 
/*--------------------------------------------------------------------------*/
    if(!horzSpan) lumaN = lumaW; 
    if(!horzSpan) lumaS = lumaE;
    if(horzSpan) lengthSign = rcpFrame.y;
    float subpixB = (subpixA * (1.0/12.0)) - lumaM;
/*--------------------------------------------------------------------------*/
    float gradientN = lumaN - lumaM;
    float gradientS = lumaS - lumaM;
    float lumaNN = lumaN + lumaM;
    float lumaSS = lumaS + lumaM;
    bool pairN = abs(gradientN) >= abs(gradientS);
    float gradient = max(abs(gradientN), abs(gradientS));
    if(pairN) lengthSign = -lengthSign;
    float subpixC = FxaaSat(abs(subpixB) * subpixRcpRange);
/*--------------------------------------------------------------------------*/
    float2 posB;
    posB.x = posM.x;
    posB.y = posM.y;
    float2 offNP;
    offNP.x = (!horzSpan) ? 0.0 : rcpFrame.x;
    offNP.y = ( horzSpan) ? 0.0 : rcpFrame.y;
    if(!horzSpan) posB.x += lengthSign * 0.5;
    if( horzSpan) posB.y += lengthSign * 0.5;
/*--------------------------------------------------------------------------*/
    float2 posN;
    posN.x = posB.x - offNP.x;
    posN.y = posB.y - offNP.y;
    float2 posP;
    posP.x = posB.x + offNP.x;
    posP.y = posB.y + offNP.y;
    float subpixD = ((-2.0)*subpixC) + 3.0;
    float lumaEndN = FxaaTexTop(tex, posN).w;
    float subpixE = subpixC * subpixC;
    float lumaEndP = FxaaTexTop(tex, posP).w;
/*--------------------------------------------------------------------------*/
    if(!pairN) lumaNN = lumaSS;
    float gradientScaled = gradient * 1.0/4.0;
    float lumaMM = lumaM - lumaNN * 0.5;
    float subpixF = subpixD * subpixE;
    bool lumaMLTZero = lumaMM < 0.0;
/*--------------------------------------------------------------------------*/
    lumaEndN -= lumaNN * 0.5;
    lumaEndP -= lumaNN * 0.5;
    bool doneN = abs(lumaEndN) >= gradientScaled;
    bool doneP = abs(lumaEndP) >= gradientScaled;
    if(!doneN) posN.x -= offNP.x * 1.5;
    if(!doneN) posN.y -= offNP.y * 1.5;
    bool doneNP = (!doneN) || (!doneP);
    if(!doneP) posP.x += offNP.x * 1.5;
    if(!doneP) posP.y += offNP.y * 1.5;
    if(doneNP) {
/*--------------------------------------------------------------------------*/
        if(!doneN) lumaEndN = FxaaTexTop(tex, posN.xy).w;
        if(!doneP) lumaEndP = FxaaTexTop(tex, posP.xy).w;
        if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
        if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
        doneN = abs(lumaEndN) >= gradientScaled;
        doneP = abs(lumaEndP) >= gradientScaled;
        if(!doneN) posN.x -= offNP.x * 2.0;
        if(!doneN) posN.y -= offNP.y * 2.0;
        doneNP = (!doneN) || (!doneP);
        if(!doneP) posP.x += offNP.x * 2.0;
        if(!doneP) posP.y += offNP.y * 2.0;
        if(doneNP) {
/*--------------------------------------------------------------------------*/
            if(!doneN) lumaEndN = FxaaTexTop(tex, posN.xy).w;
            if(!doneP) lumaEndP = FxaaTexTop(tex, posP.xy).w;
            if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
            if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
            doneN = abs(lumaEndN) >= gradientScaled;
            doneP = abs(lumaEndP) >= gradientScaled;
            if(!doneN) posN.x -= offNP.x * 2.0;
            if(!doneN) posN.y -= offNP.y * 2.0;
            doneNP = (!doneN) || (!doneP);
            if(!doneP) posP.x += offNP.x * 2.0;
            if(!doneP) posP.y += offNP.y * 2.0;
            if(doneNP) {
/*--------------------------------------------------------------------------*/
                if(!doneN) lumaEndN = FxaaTexTop(tex, posN.xy).w;
                if(!doneP) lumaEndP = FxaaTexTop(tex, posP.xy).w;
                if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
                if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
                doneN = abs(lumaEndN) >= gradientScaled;
                doneP = abs(lumaEndP) >= gradientScaled;
                if(!doneN) posN.x -= offNP.x * 4.0;
                if(!doneN) posN.y -= offNP.y * 4.0;
                doneNP = (!doneN) || (!doneP);
                if(!doneP) posP.x += offNP.x * 4.0;
                if(!doneP) posP.y += offNP.y * 4.0;
                if(doneNP) {
/*--------------------------------------------------------------------------*/
                    if(!doneN) lumaEndN = FxaaTexTop(tex, posN.xy).w;
                    if(!doneP) lumaEndP = FxaaTexTop(tex, posP.xy).w;
                    if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
                    if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
                    doneN = abs(lumaEndN) >= gradientScaled;
                    doneP = abs(lumaEndP) >= gradientScaled;
                    if(!doneN) posN.x -= offNP.x * 2.0;
                    if(!doneN) posN.y -= offNP.y * 2.0;
                    if(!doneP) posP.x += offNP.x * 2.0; 
                    if(!doneP) posP.y += offNP.y * 2.0; } } } }
/*--------------------------------------------------------------------------*/
    float dstN = posM.x - posN.x;
    float dstP = posP.x - posM.x;
    if(!horzSpan) dstN = posM.y - posN.y;
    if(!horzSpan) dstP = posP.y - posM.y;
/*--------------------------------------------------------------------------*/
    bool goodSpanN = (lumaEndN < 0.0) != lumaMLTZero;
    float spanLength = (dstP + dstN);
    bool goodSpanP = (lumaEndP < 0.0) != lumaMLTZero;
    float spanLengthRcp = 1.0/spanLength;
/*--------------------------------------------------------------------------*/
    bool directionN = dstN < dstP;
    float dst = min(dstN, dstP);
    bool goodSpan = directionN ? goodSpanN : goodSpanP;
    float subpixG = subpixF * subpixF;
    float pixelOffset = (dst * (-spanLengthRcp)) + 0.5;
    float subpixH = subpixG * FXAA_QUALITY__SUBPIX;
/*--------------------------------------------------------------------------*/
    float pixelOffsetGood = goodSpan ? pixelOffset : 0.0;
    float pixelOffsetSubpix = max(pixelOffsetGood, subpixH);
    if(!horzSpan) posM.x += pixelOffsetSubpix * lengthSign;
    if( horzSpan) posM.y += pixelOffsetSubpix * lengthSign;
    return FxaaTexTop(tex, posM); 
}
/*==========================================================================*/
#endif

technique Technique1
{
    pass Pass1
    {
        // TODO: set renderstates here.

        VertexShader = compile vs_3_0 VertexShaderFunction();
        PixelShader = compile ps_3_0 FxaaPixelShader();
    }
}
