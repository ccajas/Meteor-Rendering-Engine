
//uniform sampler2D bgl_RenderedTexture;

texture Texture;
sampler bgl_RenderedTexture : register(s4) = sampler_state
{
	Filter = MIN_MAG_MIP_POINT;
	AddressU = Clamp;
	AddressV = Clamp;
	Texture = <Texture>;
};


float bgl_RenderedTextureWidth;
float bgl_RenderedTextureHeight;

float2 halfPixel;

#define PIXEL_SIZE float2(1.0/bgl_RenderedTextureWidth, 1.0/bgl_RenderedTextureHeight)

float4 sampleOffseted(const in sampler2D tex, const in float2 texCoord, const float2 pixelOffset )
{
   return tex2D(tex, texCoord + pixelOffset * PIXEL_SIZE);
}

float3 avg(const in float3 value)
{
   static const float oneThird = 1.0 / 3.0;
   return dot(value.xyz, float3(oneThird, oneThird, oneThird) );
}


float4 firsPassEdgeDetect( float2 texCoord )
{
   float4 sCenter    = sampleOffseted(bgl_RenderedTexture, texCoord, float2( 0.0,  0.0) );
   float4 sUpLeft    = sampleOffseted(bgl_RenderedTexture, texCoord, float2(-0.5, -0.5) );
   float4 sUpRight   = sampleOffseted(bgl_RenderedTexture, texCoord, float2( 0.5, -0.5) );
   float4 sDownLeft  = sampleOffseted(bgl_RenderedTexture, texCoord, float2(-0.5,  0.5) );
   float4 sDownRight = sampleOffseted(bgl_RenderedTexture, texCoord, float2( 0.5,  0.5) );
 
   float4 diff          = abs( ((sUpLeft + sUpRight + sDownLeft + sDownRight) * 4.0) - (sCenter * 16.0) );
   float edgeMask       = avg(diff.xyz);

   return float4(sCenter.rgb, edgeMask);
}

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


float4 PixelShaderFunction(VertexShaderOutput input) : COLOR
{
	// short edges
	float4 sampleCenter     = sampleOffseted(bgl_RenderedTexture, input.TexCoord.xy, float2( 0.0,  0.0) );   
	float4 sampleHorizNeg0   = sampleOffseted(bgl_RenderedTexture, input.TexCoord.xy, float2(-1.5,  0.0) );
	float4 sampleHorizPos0   = sampleOffseted(bgl_RenderedTexture, input.TexCoord.xy, float2( 1.5,  0.0) ); 
	float4 sampleVertNeg0   = sampleOffseted(bgl_RenderedTexture, input.TexCoord.xy, float2( 0.0, -1.5) ); 
	float4 sampleVertPos0   = sampleOffseted(bgl_RenderedTexture, input.TexCoord.xy, float2( 0.0,  1.5) );

	float4 sumHoriz         = sampleHorizNeg0 + sampleHorizPos0;
	float4 sumVert          = sampleVertNeg0  + sampleVertPos0;

	float4 diffToCenterHoriz = abs(sumHoriz - (2.0 * sampleCenter) ) / 2.0;  
	float4 diffToCenterVert  = abs(sumHoriz - (2.0 * sampleCenter) ) / 2.0;

	float valueEdgeHoriz    = avg( diffToCenterHoriz.xyz );
	float valueEdgeVert     = avg( diffToCenterVert.xyz );
        
	float edgeDetectHoriz   = clamp( (3.0 * valueEdgeHoriz) - 0.1,0.0,1.0);
	float edgeDetectVert    = clamp( (3.0 * valueEdgeVert)  - 0.1,0.0,1.0);

	float4 avgHoriz         = ( sumHoriz + sampleCenter) / 3.0;
	float4 avgVert          = ( sumVert  + sampleCenter) / 3.0;

	float valueHoriz        = avg( avgHoriz.xyz );
	float valueVert         = avg( avgVert.xyz );

	float blurAmountHoriz   = clamp( edgeDetectHoriz / valueHoriz ,0.0,1.0);
	float blurAmountVert    = clamp( edgeDetectVert  / valueVert ,0.0,1.0);

	float4 aaResult         	= lerp( sampleCenter,  avgHoriz, blurAmountHoriz );
	aaResult                = lerp( aaResult,       avgVert,  blurAmountVert );
  
	// long edges
	float4 sampleVertNeg1   = sampleOffseted(bgl_RenderedTexture, input.TexCoord.xy, float2(0.0, -3.5) ); 
	float4 sampleVertNeg2   = sampleOffseted(bgl_RenderedTexture, input.TexCoord.xy, float2(0.0, -7.5) );
	float4 sampleVertPos1   = sampleOffseted(bgl_RenderedTexture, input.TexCoord.xy, float2(0.0,  3.5) ); 
	float4 sampleVertPos2   = sampleOffseted(bgl_RenderedTexture, input.TexCoord.xy, float2(0.0,  7.5) ); 

	float4 sampleHorizNeg1   = sampleOffseted(bgl_RenderedTexture, input.TexCoord.xy, float2(-3.5, 0.0) ); 
	float4 sampleHorizNeg2   = sampleOffseted(bgl_RenderedTexture, input.TexCoord.xy, float2(-7.5, 0.0) );
	float4 sampleHorizPos1   = sampleOffseted(bgl_RenderedTexture, input.TexCoord.xy, float2( 3.5, 0.0) ); 
	float4 sampleHorizPos2   = sampleOffseted(bgl_RenderedTexture, input.TexCoord.xy, float2( 7.5, 0.0) ); 

	float pass1EdgeAvgHoriz  = (sampleHorizNeg2.a + sampleHorizNeg1.a + sampleCenter.a + sampleHorizPos1.a + sampleHorizPos2.a) / 5.0;
	float pass1EdgeAvgVert   = (sampleVertNeg2.a  + sampleVertNeg1.a  + sampleCenter.a + sampleVertPos1.a  + sampleVertPos2.a) / 5.0;
	pass1EdgeAvgHoriz        = clamp(pass1EdgeAvgHoriz * 2.0 - 1.0 ,0.0,1.0);
	pass1EdgeAvgVert         = clamp(pass1EdgeAvgVert  * 2.0 - 1.0 ,0.0,1.0);
	float longEdge           = max(pass1EdgeAvgHoriz, pass1EdgeAvgVert);

	if ( longEdge > 1.0 )
	{
        float4 avgHorizLong  	= (sampleHorizNeg2 + sampleHorizNeg1 + sampleCenter + sampleHorizPos1 + sampleHorizPos2) / 5.0;
        float4 avgVertLong   	= (sampleVertNeg2  + sampleVertNeg1  + sampleCenter + sampleVertPos1  + sampleVertPos2) / 5.0;
        float valueHorizLong   	= avg(avgHorizLong.xyz);
        float valueVertLong     = avg(avgVertLong.xyz);

        float4 sampleLeft       = sampleOffseted(bgl_RenderedTexture, input.TexCoord.xy, float2(-1.0,  0.0) );
        float4 sampleRight   	  = sampleOffseted(bgl_RenderedTexture, input.TexCoord.xy, float2( 1.0,  0.0) );
        float4 sampleUp         = sampleOffseted(bgl_RenderedTexture, input.TexCoord.xy, float2( 0.0, -1.0) );
        float4 sampleDown       = sampleOffseted(bgl_RenderedTexture, input.TexCoord.xy, float2( 0.0,  1.0) );

        float valueCenter       = avg(sampleCenter.xyz);
        float valueLeft         = avg(sampleLeft.xyz);
        float valueRight        = avg(sampleRight.xyz);
        float valueTop          = avg(sampleUp.xyz);
        float valueBottom       = avg(sampleDown.xyz);

        float4 diffToCenter  		= valueCenter - float4(valueLeft, valueTop, valueRight, valueBottom);      
        float blurAmountLeft 	= clamp( 0.0 + (valueVertLong  - valueLeft) / diffToCenter.x ,0.0,1.0);
        float blurAmountUp   	= clamp( 0.0 + (valueHorizLong - valueTop) / diffToCenter.y ,0.0,1.0);
        float blurAmountRight	= clamp( 1.0 + (valueVertLong  - valueCenter) / diffToCenter.z ,0.0,1.0);
        float blurAmountDown 	= clamp( 1.0 + (valueHorizLong - valueCenter) / diffToCenter.w ,0.0,1.0);     

        float4 blurAmounts   	= float4( blurAmountLeft, blurAmountRight, blurAmountUp, blurAmountDown );
        blurAmounts             = (blurAmounts == float4(0.0, 0.0, 0.0, 0.0)) ? float4(1.0, 1.0, 1.0, 1.0) : blurAmounts;

        float4 longBlurHoriz 	= lerp( sampleLeft,  sampleCenter,  blurAmounts.x );
        longBlurHoriz           = lerp( sampleRight, longBlurHoriz, blurAmounts.y );
        float4 longBlurVert  	= lerp( sampleUp,  sampleCenter,  blurAmounts.z );
        longBlurVert            = lerp( sampleDown,  longBlurVert,  blurAmounts.w );

        aaResult                = lerp( aaResult, longBlurHoriz, pass1EdgeAvgVert);
        aaResult                = lerp( aaResult, longBlurVert,  pass1EdgeAvgHoriz);
	}

	return float4(aaResult.rgb, 1.0);
}

technique Technique1
{
    pass Pass1
    {
        VertexShader = compile vs_3_0 VertexShaderFunction();
        PixelShader = compile ps_3_0 PixelShaderFunction();
    }
}
