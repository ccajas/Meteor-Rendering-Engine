
/**
 * Copyright (C) 2011 Jorge Jimenez (jorge@iryoku.com)
 * Copyright (C) 2011 Belen Masia (bmasia@unizar.es) 
 * Copyright (C) 2011 Jose I. Echevarria (joseignacioechevarria@gmail.com) 
 * Copyright (C) 2011 Fernando Navarro (fernandn@microsoft.com) 
 * Copyright (C) 2011 Diego Gutierrez (diegog@unizar.es)
 * All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 * 
 *    1. Redistributions of source code must retain the above copyright notice,
 *       this list of conditions and the following disclaimer.
 * 
 *    2. Redistributions in binary form must reproduce the following disclaimer
 *       in the documentation and/or other materials provided with the 
 *       distribution:
 * 
 *      "Uses SMAA. Copyright (C) 2011 by Jorge Jimenez, Jose I. Echevarria,
 *       Belen Masia, Fernando Navarro and Diego Gutierrez."
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS ``AS 
 * IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, 
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR 
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL COPYRIGHT HOLDERS OR CONTRIBUTORS 
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
 * POSSIBILITY OF SUCH DAMAGE.
 * 
 * The views and conclusions contained in the software and documentation are 
 * those of the authors and should not be interpreted as representing official
 * policies, either expressed or implied, of the copyright holders.
 */


/**
 *                  _______  ___  ___       ___           ___
 *                 /       ||   \/   |     /   \         /   \
 *                |   (---- |  \  /  |    /  ^  \       /  ^  \
 *                 \   \    |  |\/|  |   /  /_\  \     /  /_\  \
 *              ----)   |   |  |  |  |  /  _____  \   /  _____  \
 *             |_______/    |__|  |__| /__/     \__\ /__/     \__\
 * 
 *                               E N H A N C E D
 *       S U B P I X E L   M O R P H O L O G I C A L   A N T I A L I A S I N G
 *
 *                         http://www.iryoku.com/smaa/
 *
 * Hi, welcome aboard!
 * 
 * Here you'll find instructions to get the shader up and running as fast as
 * possible.
 *
 * The shader has three passes, chained together as follows:
 *
 *                           |input|------------------�
 *                              v                     |
 *                    [ SMAA*EdgeDetection ]          |
 *                              v                     |
 *                          |edgesTex|                |
 *                              v                     |
 *              [ SMAABlendingWeightCalculation ]     |
 *                              v                     |
 *                          |blendTex|                |
 *                              v                     |
 *                [ SMAANeighborhoodBlending ] <------�
 *                              v
 *                           |output|
 *
 * Note that each [pass] has its own vertex and pixel shader.
 *
 * You've three edge detection methods to choose from: luma, color or depth.
 * They represent different quality/performance and anti-aliasing/sharpness
 * tradeoffs, so our recommendation is for you to choose the one that suits
 * better your particular scenario:
 *
 * - Depth edge detection is usually the faster but it may miss some edges.
 *
 * - Luma edge detection is usually more expensive than depth edge detection,
 *   but catches visible edges that depth edge detection can miss.
 *
 * - Color edge detection is usually the most expensive one but catches
 *   chroma-only edges.
 *
 * For quickstarters: just use luma edge detection.
 *
 * Ok then, let's go!
 *
 *  1. The first step is to create two RGBA temporal framebuffers for holding
 *     |edgesTex| and |blendTex|. In DX10, you can use a RG framebuffer for the
 *     edges texture, but in our experience it yields worse performance.
 *
 *  2. Both temporal framebuffers |edgesTex| and |blendTex| must be cleared
 *     each frame. Do not forget to clear the alpha channel!
 *
 *  3. The next step is loading the two supporting precalculated textures,
 *     'areaTex' and 'searchTex'. You'll find them in the 'Textures' folder as
 *     C++ headers, and also as regular DDS files. They'll be needed for the
 *     'SMAABlendingWeightCalculation' pass.
 *
 *     If you use the C++ headers, be sure to load them in the format specified
 *     inside of them.
 *
 *  4. In DX9, all samplers must be set to linear filtering and clamp, with the
 *     exception of 'searchTex', which must be set to point filtering.
 *
 *  5. All texture reads and buffer writes must be non-sRGB, with the exception
 *     of the input read and the output write of input in 
 *     'SMAANeighborhoodBlending' (and only in this pass!). If sRGB reads in
 *     this last pass are not possible, the technique will work anyways, but
 *     will perform antialiasing in gamma space. 
 *
 *     IMPORTANT: for best results the input read for the color/luma edge 
 *     detection should *NOT* be sRGB.
 *
 *  6. Before including SMAA.h you'll have to setup the framebuffer pixel size,
 *     the target and any optional configuration defines. Optionally you can
 *     use a preset.
 *
 *     You have three targets available: 
 *         SMAA_HLSL_3
 *         SMAA_HLSL_4
 *         SMAA_HLSL_4_1
 *
 *     And four presets:
 *         SMAA_PRESET_LOW          (%60 of the quality)
 *         SMAA_PRESET_MEDIUM       (%80 of the quality)
 *         SMAA_PRESET_HIGH         (%95 of the quality)
 *         SMAA_PRESET_ULTRA        (%99 of the quality)
 *         
 *     For example:
 *         #define SMAA_PIXEL_SIZE float2(1.0 / 1280.0, 1.0 / 720.0)
 *         #define SMAA_HLSL_4 1 
 *         #define SMAA_PRESET_HIGH 1
 *         #include "SMAA.h"
 *
 *  7. Then, you'll have to setup the passes as indicated in the scheme above.
 *     You can take a look into SMAA.fx, to see how we did it for our demo.
 *     Checkout the function wrappers, you may want to copy-paste them!
 *
 *  8. It's recommended to validate the produced |edgesTex| and |blendTex|.
 *     It's advised to not continue with the implementation until both buffers
 *     are verified to produce identical results to our reference demo.
 *
 *  9. After you get the last pass to work, it's time to optimize. You'll have
 *     to initialize a stencil buffer in the first pass (discard is already in
 *     the code), then mask execution by using it the second pass. The last
 *     pass should be executed in all pixels.
 *
 * That is it!
 */

#define SMAA_PIXEL_SIZE float2(1.0 / 1280.0, 1.0 / 720.0)
#define SMAA_HLSL_3 1 
#define SMAA_PRESET_HIGH 1
//#include "SMAA.h"
 
float2 halfPixel;

///////////////////
// VERTEX SHADER //
///////////////////

struct VSOUT
{
	float4 vertPos : POSITION;
	float2 UVCoord : TEXCOORD0;
};

struct VSIN
{
	float4 vertPos : POSITION0;
	float2 UVCoord : TEXCOORD0;
};

VSOUT FrameVS(VSIN IN)
{
	VSOUT OUT = (VSOUT)0.0f;	// initialize to zero, avoid complaints.
	OUT.vertPos = IN.vertPos;
	OUT.UVCoord = IN.UVCoord - halfPixel;
	return OUT;
}

//-----------------------------------------------------------------------------
// SMAA Presets

#if SMAA_PRESET_LOW == 1
#define SMAA_THRESHOLD 0.15
#define SMAA_MAX_SEARCH_STEPS 4
#define SMAA_MAX_SEARCH_STEPS_DIAG 0
#define SMAA_CORNER_ROUNDING 100
#elif SMAA_PRESET_MEDIUM == 1
#define SMAA_THRESHOLD 0.1
#define SMAA_MAX_SEARCH_STEPS 8
#define SMAA_MAX_SEARCH_STEPS_DIAG 0
#define SMAA_CORNER_ROUNDING 100
#elif SMAA_PRESET_HIGH == 1
#define SMAA_THRESHOLD 0.1
#define SMAA_MAX_SEARCH_STEPS 16
#define SMAA_MAX_SEARCH_STEPS_DIAG 8
#define SMAA_CORNER_ROUNDING 25
#elif SMAA_PRESET_ULTRA == 1
#define SMAA_THRESHOLD 0.05
#define SMAA_MAX_SEARCH_STEPS 32
#define SMAA_MAX_SEARCH_STEPS_DIAG 16
#define SMAA_CORNER_ROUNDING 25
#endif

//-----------------------------------------------------------------------------
// Configurable Defines

/**
 * SMAA_THRESHOLD specifies the threshold or sensitivity to edges.
 * Lowering this value you will be able to detect more edges at the expense of
 * performance. 
 *
 * Range: [0.0 .. 0.5]
 *   0.1 is a reasonable value, and allows to catch most visible edges.
 *   0.05 is a rather overkill value, that allows to catch 'em all.
 */
#ifndef SMAA_THRESHOLD
#define SMAA_THRESHOLD 0.1
#endif

/**
 * SMAA_DEPTH_THRESHOLD specifies the threshold for depth edge detection.
 * 
 * Range: depends on the depth range of the scene.
 */
#ifndef SMAA_DEPTH_THRESHOLD
#define SMAA_DEPTH_THRESHOLD (0.1 * SMAA_THRESHOLD)
#endif

/**
 * SMAA_MAX_SEARCH_STEPS specifies the maximum steps performed in the
 * horizontal/vertical pattern searches, at each side of the pixel.
 *
 * In number of pixels, it's actually the double. So the maximum line length
 * perfectly handled by, for example 16, is 64 (by perfectly, we meant that
 * longer lines won't look as good, but still antialiased).
 *
 * Range: [0 .. 98]
 */
#ifndef SMAA_MAX_SEARCH_STEPS
#define SMAA_MAX_SEARCH_STEPS 16
#endif

/**
 * SMAA_MAX_SEARCH_STEPS_DIAG specifies the maximum steps performed in the
 * diagonal pattern searchs, at each side of the pixel. In this case we jump
 * one pixel at time, instead of two.
 *
 * Range: [0 .. 20]; set it to 0 to disable diagonal processing.
 *
 * On high-end machines it is cheap (between a 0.8x and 0.9x slower for 16 
 * steps), but it can have a significant impact on older machines.
 */
#ifndef SMAA_MAX_SEARCH_STEPS_DIAG
#define SMAA_MAX_SEARCH_STEPS_DIAG 8
#endif

/**
 * SMAA_CORNER_ROUNDING specifies how much sharp corners will be rounded.
 *
 * Range: [0 .. 100]; set it to 100 to disable corner detection.
 */
#ifndef SMAA_CORNER_ROUNDING
#define SMAA_CORNER_ROUNDING 25
#endif

/**
 * Predicated thresholding allows to better preserve texture details and to
 * improve performance, by decreasing the number of detected edges using an
 * additional buffer like the light accumulation buffer, object ids or even the
 * depth buffer.
 *
 * It locally decreases the luma or color threshold if an edge is found in an
 * additional buffer (so the global threshold can be higher).
 *
 * This method was developed by Playstation EDGE MLAA team, and used in 
 * Killzone 3, by using the light accumulation buffer. More information here:
 *     http://iryoku.com/aacourse/downloads/06-MLAA-on-PS3.pptx 
 */
#ifndef SMAA_PREDICATION
#define SMAA_PREDICATION 0
#endif

/**
 * Threshold to be used in the additional predication buffer. 
 *
 * Range: depends on the input, so you'll have to find the magic number that
 * works for you.
 */
#ifndef SMAA_PREDICATION_THRESHOLD
#define SMAA_PREDICATION_THRESHOLD 0.01
#endif

/**
 * How much to scale the global threshold used for luma or color edge
 * detection when using predication.
 *
 * Range: [1 .. 5]
 */
#ifndef SMAA_PREDICATION_SCALE
#define SMAA_PREDICATION_SCALE 2.0
#endif

/**
 * How much to locally decrease the threshold.
 *
 * Range: [0 .. 1]
 */
#ifndef SMAA_PREDICATION_STRENGTH
#define SMAA_PREDICATION_STRENGTH 0.4
#endif

/**
 * In the last pass we leverage bilinear filtering to avoid some lerps.
 * However, bilinear filtering is done in gamma space in DX9, under DX9
 * hardware (but not in DX9 code running on DX10 hardware), which gives
 * inaccurate results.
 *
 * So, if you are in DX9, under DX9 hardware, and do you want accurate linear
 * blending, you must set this flag to 1.
 *
 * It's ignored when using SMAA_HLSL_4, and of course, only has sense when
 * using sRGB read and writes on the last pass.
 */
#ifndef SMAA_DIRECTX9_LINEAR_BLEND
#define SMAA_DIRECTX9_LINEAR_BLEND 0
#endif

//-----------------------------------------------------------------------------
// Non-Configurable Defines

#ifndef SMAA_AREATEX_MAX_DISTANCE
#define SMAA_AREATEX_MAX_DISTANCE 16
#endif
#ifndef SMAA_AREATEX_MAX_DISTANCE_DIAG
#define SMAA_AREATEX_MAX_DISTANCE_DIAG 20
#endif
#define SMAA_AREATEX_PIXEL_SIZE (1.0 / float2(160.0, 80.0))

//-----------------------------------------------------------------------------
// Porting Functions

#if SMAA_HLSL_3 == 1
#define SMAATexture2D sampler2D
#define SMAASampleLevelZero(tex, coord) tex2Dlod(tex, float4(coord, 0.0, 0.0))
#define SMAASampleLevelZeroPoint(tex, coord) tex2Dlod(tex, float4(coord, 0.0, 0.0))
#define SMAASample(tex, coord) tex2D(tex, coord)
#define SMAASampleLevelZeroOffset(tex, coord, off) tex2Dlod(tex, float4(coord + off * SMAA_PIXEL_SIZE, 0.0, 0.0))
#define SMAASampleOffset(tex, coord, off) tex2D(tex, coord + off * SMAA_PIXEL_SIZE)
#endif
#if SMAA_HLSL_4 == 1 || SMAA_HLSL_4_1 == 1
SamplerState LinearSampler {
    Filter = MIN_MAG_LINEAR_MIP_POINT;
    AddressU = Clamp;
    AddressV = Clamp;
};
SamplerState PointSampler {
    Filter = MIN_MAG_MIP_POINT;
    AddressU = Clamp;
    AddressV = Clamp;
};
#define SMAATexture2D Texture2D
#define SMAASampleLevelZero(tex, coord) tex.SampleLevel(LinearSampler, coord, 0)
#define SMAASampleLevelZeroPoint(tex, coord) tex.SampleLevel(PointSampler, coord, 0)
#define SMAASample(tex, coord) SMAASampleLevelZero(tex, coord)
#define SMAASampleLevelZeroOffset(tex, coord, off) tex.SampleLevel(LinearSampler, coord, 0, off)
#define SMAASampleOffset(tex, coord, off) SMAASampleLevelZeroOffset(tex, coord, off)
#endif
#if SMAA_HLSL_4_1 == 1
#define SMAAGather(tex, coord) tex.Gather(LinearSampler, coord, 0)
#endif

//-----------------------------------------------------------------------------
// Misc functions

/**
 * Gathers current pixel, and the top-left neighbours.
 */
float3 SMAAGatherNeighbours(float2 texcoord,
                            float4 offset[2],
                            SMAATexture2D tex) {
    #if SMAA_HLSL_4_1 == 1
    return SMAAGather(tex, texcoord + SMAA_PIXEL_SIZE * float2(-0.5, -0.5)).grb;
    #else
    float P = SMAASample(tex, texcoord).r;
    float Pleft = SMAASample(tex, offset[0].xy).r;
    float Ptop  = SMAASample(tex, offset[0].zw).r;
    return float3(P, Pleft, Ptop);
    #endif
}

/**
 * Adjusts the threshold by means of predication.
 */
float2 SMAACalculatePredicatedThreshold(float2 texcoord,
                                        float4 offset[2],
                                        SMAATexture2D colorTex,
                                        SMAATexture2D predicationTex) {
    float3 neighbours = SMAAGatherNeighbours(texcoord, offset, predicationTex);
    float2 delta = abs(neighbours.xx - float2(neighbours.y, neighbours.z));
    float2 edges = step(SMAA_PREDICATION_THRESHOLD, delta);
    return SMAA_PREDICATION_SCALE * SMAA_THRESHOLD * (1.0 - SMAA_PREDICATION_STRENGTH * edges);
}

//-----------------------------------------------------------------------------
// Vertex Shaders

/**
 * Edge Detection Vertex Shader
 */
void SMAAEdgeDetectionVS(float4 position,
                         out float4 svPosition,
                         inout float2 texcoord,
                         out float4 offset[2]) {
    svPosition = position;

    offset[0] = texcoord.xyxy + SMAA_PIXEL_SIZE.xyxy * float4(-1.0, 0.0, 0.0, -1.0);
    offset[1] = texcoord.xyxy + SMAA_PIXEL_SIZE.xyxy * float4( 1.0, 0.0, 0.0,  1.0);
}

/**
 * Blend Weight Calculation Vertex Shader
 */
void SMAABlendWeightCalculationVS(float4 position,
                                  out float4 svPosition,
                                  inout float2 texcoord,
                                  out float2 pixcoord,
                                  out float4 offset[3]) {
    svPosition = position;

    pixcoord = texcoord / SMAA_PIXEL_SIZE;

    // We will use these offsets for the searchs later on (see @PSEUDO_GATHER4):
    offset[0] = texcoord.xyxy + SMAA_PIXEL_SIZE.xyxy * float4(-0.25, -0.125,  1.25, -0.125);
    offset[1] = texcoord.xyxy + SMAA_PIXEL_SIZE.xyxy * float4(-0.125, -0.25, -0.125,  1.25);

    // And these for the searchs, they indicate the ends of the loops:
    offset[2] = float4(offset[0].xz, offset[1].yw) + 
                float4(-2.0, 2.0, -2.0, 2.0) *
                SMAA_PIXEL_SIZE.xxyy * SMAA_MAX_SEARCH_STEPS;
}

/**
 * Neighborhood Blending Vertex Shader
 */
void SMAANeighborhoodBlendingVS(float4 position,
                                out float4 svPosition,
                                inout float2 texcoord,
                                out float4 offset[2]) {
    svPosition = position;

    offset[0] = texcoord.xyxy + SMAA_PIXEL_SIZE.xyxy * float4(-1.0, 0.0, 0.0, -1.0);
    offset[1] = texcoord.xyxy + SMAA_PIXEL_SIZE.xyxy * float4( 1.0, 0.0, 0.0,  1.0);
}

//-----------------------------------------------------------------------------
// Edge Detection Pixel Shaders (First Pass)

/**
 * Luma Edge Detection
 *
 * IMPORTANT NOTICE: luma edge detection requires gamma-corrected colors, and
 * thus 'colorTex' should be a non-sRGB texture.
 */
float4 SMAALumaEdgeDetectionPS(float2 texcoord,
                               float4 offset[2],
                               SMAATexture2D colorTex
                               #if SMAA_PREDICATION == 1
                               , SMAATexture2D predicationTex
                               #endif
                               ) {
    // Calculate the threshold:
    #if SMAA_PREDICATION == 1
    float2 threshold = SMAACalculatePredicatedThreshold(texcoord, offset, colorTex, predicationTex);
    #else
    float2 threshold = SMAA_THRESHOLD;
    #endif

    // Calculate lumas:
    float3 weights = float3(0.2126, 0.7152, 0.0722);
    float L = dot(SMAASample(colorTex, texcoord).rgb, weights);
    float Lleft = dot(SMAASample(colorTex, offset[0].xy).rgb, weights);
    float Ltop  = dot(SMAASample(colorTex, offset[0].zw).rgb, weights);

    // We do the usual threshold:
    float4 delta;
    delta.xy = abs(L.xx - float2(Lleft, Ltop));
    float2 edges = step(threshold, delta.xy);

    // Then discard if there is no edge:
    if (dot(edges, 1.0) == 0.0)
        discard;

    // Calculate right and bottom deltas:
    float Lright = dot(SMAASample(colorTex, offset[1].xy).rgb, weights);
    float Lbottom  = dot(SMAASample(colorTex, offset[1].zw).rgb, weights);
    delta.zw = abs(L.xx - float2(Lright, Lbottom));

    /**
     * Each edge with a delta in luma of less than 50% of the maximum luma
     * surrounding this pixel is discarded. This allows to eliminate spurious
     * crossing edges, and is based on the fact that, if there is too much
     * contrast in a direction, that will hide contrast in the other
     * neighbors.
     * This is done after the discard intentionally as this situation doesn't
     * happen too frequently (but it's important to do as it prevents some 
     * edges from going undetected).
     */
    float maxDelta = max(max(max(delta.x, delta.y), delta.z), delta.w);
    edges.xy *= step(0.5 * maxDelta, delta.xy);

    return float4(edges, 0.0, 0.0);
}

/**
 * Color Edge Detection
 *
 * IMPORTANT NOTICE: color edge detection requires gamma-corrected colors, and
 * thus 'colorTex' should be a non-sRGB texture.
 */
float4 SMAAColorEdgeDetectionPS(float2 texcoord,
                                float4 offset[2],
                                SMAATexture2D colorTex
                                #if SMAA_PREDICATION == 1
                                , SMAATexture2D predicationTex
                                #endif
                                ) {
    // Calculate the threshold:
    #if SMAA_PREDICATION == 1
    float2 threshold = SMAACalculatePredicatedThreshold(texcoord, offset, colorTex, predicationTex);
    #else
    float2 threshold = SMAA_THRESHOLD;
    #endif

    // Calculate color deltas:
    float4 delta;
    float3 C = SMAASample(colorTex, texcoord).rgb;

    float3 Cleft = SMAASample(colorTex, offset[0].xy).rgb;
    float3 t = abs(C - Cleft);
    delta.x = max(max(t.r, t.g), t.b);

    float3 Ctop  = SMAASample(colorTex, offset[0].zw).rgb;
    t = abs(C - Ctop);
    delta.y = max(max(t.r, t.g), t.b);

    // We do the usual threshold:
    float2 edges = step(threshold, delta.xy);

    // Then discard if there is no edge:
    if (dot(edges, 1.0) == 0.0)
        discard;

    // Calculate right and bottom deltas:
    float3 Cright = SMAASample(colorTex, offset[1].xy).rgb;
    t = abs(C - Cright);
    delta.z = max(max(t.r, t.g), t.b);

    float3 Cbottom  = SMAASample(colorTex, offset[1].zw).rgb;
    t = abs(C - Cbottom);
    delta.w = max(max(t.r, t.g), t.b);

    /**
     * Each edge with a delta in luma of less than 50% of the maximum luma
     * surrounding this pixel is discarded. This allows to eliminate spurious
     * crossing edges, and is based on the fact that, if there is too much
     * contrast in a direction, that will hide contrast in the other
     * neighbors.
     * This is done after the discard intentionally as this situation doesn't
     * happen too frequently (but it's important to do as it prevents some 
     * edges from going undetected).
     */
    float maxDelta = max(max(max(delta.x, delta.y), delta.z), delta.w);
    edges.xy *= step(0.5 * maxDelta, delta.xy);

    return float4(edges, 0.0, 0.0);
}

/**
 * Depth Edge Detection
 */
float4 SMAADepthEdgeDetectionPS(float2 texcoord,
                                float4 offset[2],
                                SMAATexture2D depthTex) {
    float3 neighbours = SMAAGatherNeighbours(texcoord, offset, depthTex);
    float2 delta = abs(neighbours.xx - float2(neighbours.y, neighbours.z));
    float2 edges = step(SMAA_DEPTH_THRESHOLD, delta);

    if (dot(edges, 1.0) == 0.0)
        discard;

    return float4(edges, 0.0, 0.0);
}

//-----------------------------------------------------------------------------
// Diagonal Search Functions

#if SMAA_MAX_SEARCH_STEPS_DIAG > 0 || SMAA_FORCE_DIAGONAL_DETECTION == 1

/**
 * These functions allows to perform diagonal pattern searches.
 */
float SMAASearchDiag1(SMAATexture2D edgesTex, float2 texcoord, float2 dir, float c) {
    texcoord += dir * SMAA_PIXEL_SIZE;
    float2 e = 0;
    for (float i = 0; i < SMAA_MAX_SEARCH_STEPS_DIAG; i++) {
        e.rg = SMAASampleLevelZero(edgesTex, texcoord).rg;
        [flatten] if (dot(e, 1.0) < 1.9) break;
        texcoord += dir * SMAA_PIXEL_SIZE;
    }
    return i + float(e.g > 0.9) * c;
}

float SMAASearchDiag2(SMAATexture2D edgesTex, float2 texcoord, float2 dir, float c) {
    texcoord += dir * SMAA_PIXEL_SIZE;
    float2 e = 0;
    for (float i = 0; i < SMAA_MAX_SEARCH_STEPS_DIAG; i++) {
        e.g = SMAASampleLevelZero(edgesTex, texcoord).g;
        e.r = SMAASampleLevelZeroOffset(edgesTex, texcoord, int2(1, 0)).r;
        [flatten] if (dot(e, 1.0) < 1.9) break;
        texcoord += dir * SMAA_PIXEL_SIZE;
    }
    return i + float(e.g > 0.9) * c;
}

/** 
 * Similar to SMAAArea, this calculates the area corresponding to a certain
 * diagonal distance and crossing edges 'e'.
 */
float2 SMAAAreaDiag(SMAATexture2D areaTex, float2 distance, float2 e) {
    float2 texcoord = SMAA_AREATEX_MAX_DISTANCE_DIAG * e + distance;

    // We do a scale and bias for mapping to texel space:
    texcoord = SMAA_AREATEX_PIXEL_SIZE * texcoord + (0.5 * SMAA_AREATEX_PIXEL_SIZE);

    // Diagonal areas are on the second half of the texture:
    texcoord.x += 0.5;

    // Do it!
    #if SMAA_HLSL_3 == 1
    return SMAASampleLevelZero(areaTex, texcoord).ra;
    #else
    return SMAASampleLevelZero(areaTex, texcoord).rg;
    #endif
}

/**
 * This searches for diagonal patterns and returns the corresponding weights.
 */
float2 SMAACalculateDiagWeights(SMAATexture2D edgesTex, SMAATexture2D areaTex, float2 texcoord, float2 e) {
    float2 weights = 0.0;

    float2 d;
    d.x = e.r? SMAASearchDiag1(edgesTex, texcoord, float2(-1.0,  1.0), 1.0) : 0.0;
    d.y = SMAASearchDiag1(edgesTex, texcoord, float2(1.0, -1.0), 0.0);

    [branch]
    if (d.r + d.g > 1) { // d.r + d.g + 1 > 2
        float4 coords = mad(float4(-d.r, d.r, d.g, -d.g), SMAA_PIXEL_SIZE.xyxy, texcoord.xyxy);

        float4 c;
        c.x = SMAASampleLevelZeroOffset(edgesTex, coords.xy, int2(-1,  0)).g;
        c.y = SMAASampleLevelZeroOffset(edgesTex, coords.xy, int2( 0,  0)).r;
        c.z = SMAASampleLevelZeroOffset(edgesTex, coords.zw, int2( 1,  0)).g;
        c.w = SMAASampleLevelZeroOffset(edgesTex, coords.zw, int2( 1, -1)).r;
        float2 e = 2.0 * c.xz + c.yw;
        e *= step(d.rg, SMAA_MAX_SEARCH_STEPS_DIAG - 1);

        weights += SMAAAreaDiag(areaTex, d, e);
    }

    d.x = SMAASearchDiag2(edgesTex, texcoord, float2(-1.0, -1.0), 0.0);
    float right = SMAASampleLevelZeroOffset(edgesTex, texcoord, int2(1, 0)).r;
    d.y = right? SMAASearchDiag2(edgesTex, texcoord, float2(1.0, 1.0), 1.0) : 0.0;

    [branch]
    if (d.r + d.g > 1) { // d.r + d.g + 1 > 2
        float4 coords = mad(float4(-d.r, -d.r, d.g, d.g), SMAA_PIXEL_SIZE.xyxy, texcoord.xyxy);

        float4 c;
        c.x  = SMAASampleLevelZeroOffset(edgesTex, coords.xy, int2(-1,  0)).g;
        c.y  = SMAASampleLevelZeroOffset(edgesTex, coords.xy, int2( 0, -1)).r;
        c.zw = SMAASampleLevelZeroOffset(edgesTex, coords.zw, int2( 1,  0)).gr;
        float2 e = 2.0 * c.xz + c.yw;
        e *= step(d.rg, SMAA_MAX_SEARCH_STEPS_DIAG - 1);

        weights += SMAAAreaDiag(areaTex, d, e).gr;
    }

    return weights;
}
#endif

//-----------------------------------------------------------------------------
// Horizontal/Vertical Search Functions

/**
 * This allows to determine how much length should we add in the last step
 * of the searches. It takes the bilinearly interpolated edge (see 
 * @PSEUDO_GATHER4), and adds 0, 1 or 2, depending on which edges and
 * crossing edges are active.
 */
float SMAASearchLength(SMAATexture2D searchTex, float2 e, float bias, float scale) {
    // Not required if searchTex accesses are set to point:
    // float2 SEARCH_TEX_PIXEL_SIZE = 1.0 / float2(66.0, 33.0);
    // e = float2(bias, 0.0) + 0.5 * SEARCH_TEX_PIXEL_SIZE + 
    //     e * float2(scale, 1.0) * float2(64.0, 32.0) * SEARCH_TEX_PIXEL_SIZE;
    e.r = bias + e.r * scale;
    return 255.0 * SMAASampleLevelZeroPoint(searchTex, e).r;
}

/**
 * Horizontal/vertical search functions for the 2nd pass.
 */
float SMAASearchXLeft(SMAATexture2D edgesTex, SMAATexture2D searchTex, float2 texcoord, float end) {
    /**
     * @PSEUDO_GATHER4
     * This texcoord has been offset by (-0.25, -0.125) in the vertex shader to
     * sample between edge, thus fetching four edges in a row.
     * Sampling with different offsets in each direction allows to disambiguate
     * which edges are active from the four fetched ones.
     */
    float2 e = float2(0.0, 1.0);
    while (texcoord.x > end && 
           e.g > 0.8281 && // Is there some edge not activated?
           e.r == 0.0) { // Or is there a crossing edge that breaks the line?
        e = SMAASampleLevelZero(edgesTex, texcoord).rg;
        texcoord -= float2(2.0, 0.0) * SMAA_PIXEL_SIZE;
    }

    // We correct the previous (-0.25, -0.125) offset we applied:
    texcoord.x += 0.25 * SMAA_PIXEL_SIZE.x;

    // The searches are bias by 1, so adjust the coords accordingly:
    texcoord.x += SMAA_PIXEL_SIZE.x;

    // Disambiguate the length added by the last step:
    texcoord.x += 2.0 * SMAA_PIXEL_SIZE.x; // Undo last step
    texcoord.x -= SMAA_PIXEL_SIZE.x * SMAASearchLength(searchTex, e, 0.0, 0.5);

    return texcoord.x;
}

float SMAASearchXRight(SMAATexture2D edgesTex, SMAATexture2D searchTex, float2 texcoord, float end) {
    float2 e = float2(0.0, 1.0);
    while (texcoord.x < end && 
           e.g > 0.8281 && // Is there some edge not activated?
           e.r == 0.0) { // Or is there a crossing edge that breaks the line?
        e = SMAASampleLevelZero(edgesTex, texcoord).rg;
        texcoord += float2(2.0, 0.0) * SMAA_PIXEL_SIZE;
    }

    texcoord.x -= 0.25 * SMAA_PIXEL_SIZE.x;
    texcoord.x -= SMAA_PIXEL_SIZE.x;
    texcoord.x -= 2.0 * SMAA_PIXEL_SIZE.x;
    texcoord.x += SMAA_PIXEL_SIZE.x * SMAASearchLength(searchTex, e, 0.5, 0.5);
    return texcoord.x;
}

float SMAASearchYUp(SMAATexture2D edgesTex, SMAATexture2D searchTex, float2 texcoord, float end) {
    float2 e = float2(1.0, 0.0);
    while (texcoord.y > end && 
           e.r > 0.8281 && // Is there some edge not activated?
           e.g == 0.0) { // Or is there a crossing edge that breaks the line?
        e = SMAASampleLevelZero(edgesTex, texcoord).rg;
        texcoord -= float2(0.0, 2.0) * SMAA_PIXEL_SIZE;
    }

    texcoord.y += 0.25 * SMAA_PIXEL_SIZE.y;
    texcoord.y += SMAA_PIXEL_SIZE.y;
    texcoord.y += 2.0 * SMAA_PIXEL_SIZE.y;
    texcoord.y -= SMAA_PIXEL_SIZE.y * SMAASearchLength(searchTex, e.gr, 0.0, 0.5);
    return texcoord.y;
}

float SMAASearchYDown(SMAATexture2D edgesTex, SMAATexture2D searchTex, float2 texcoord, float end) {
    float2 e = float2(1.0, 0.0);
    while (texcoord.y < end && 
           e.r > 0.8281 && // Is there some edge not activated?
           e.g == 0.0) { // Or is there a crossing edge that breaks the line?
        e = SMAASampleLevelZero(edgesTex, texcoord).rg;
        texcoord += float2(0.0, 2.0) * SMAA_PIXEL_SIZE;
    }
    
    texcoord.y -= 0.25 * SMAA_PIXEL_SIZE.y;
    texcoord.y -= SMAA_PIXEL_SIZE.y;
    texcoord.y -= 2.0 * SMAA_PIXEL_SIZE.y;
    texcoord.y += SMAA_PIXEL_SIZE.y * SMAASearchLength(searchTex, e.gr, 0.5, 0.5);
    return texcoord.y;
}

/** 
 * Ok, we have the distance and both crossing edges. So, what are the areas
 * at each side of current edge?
 */
float2 SMAAArea(SMAATexture2D areaTex, float2 distance, float e1, float e2) {
    // Rounding prevents precision errors of bilinear filtering:
    float2 texcoord = SMAA_AREATEX_MAX_DISTANCE * round(4.0 * float2(e1, e2)) + distance;
    
    // We do a scale and bias for mapping to texel space:
    texcoord = SMAA_AREATEX_PIXEL_SIZE * texcoord + (0.5 * SMAA_AREATEX_PIXEL_SIZE);

    // Do it!
    #if SMAA_HLSL_3 == 1
    return SMAASampleLevelZero(areaTex, texcoord).ra;
    #else
    return SMAASampleLevelZero(areaTex, texcoord).rg;
    #endif
}

//-----------------------------------------------------------------------------
// Corner Detection Functions

void SMAADetectHorizontalCornerPattern(SMAATexture2D edgesTex, inout float2 weights, float2 texcoord, float2 d) {
    #if SMAA_CORNER_ROUNDING < 100 || SMAA_FORCE_CORNER_DETECTION == 1
    float4 coords = mad(float4(d.x, 0.0, d.y, 0.0),
                        SMAA_PIXEL_SIZE.xyxy, texcoord.xyxy);
    float2 e;
    e.r = SMAASampleLevelZeroOffset(edgesTex, coords.xy, int2(0.0,  1.0)).r;
    bool left = abs(d.x) < abs(d.y);
    e.g = SMAASampleLevelZeroOffset(edgesTex, coords.xy, int2(0.0, -2.0)).r;
    if (left) weights *= saturate(SMAA_CORNER_ROUNDING / 100.0 + 1.0 - e);

    e.r = SMAASampleLevelZeroOffset(edgesTex, coords.zw, int2(1.0,  1.0)).r;
    e.g = SMAASampleLevelZeroOffset(edgesTex, coords.zw, int2(1.0, -2.0)).r;
    if (!left) weights *= saturate(SMAA_CORNER_ROUNDING / 100.0 + 1.0 - e);
    #endif
}

void SMAADetectVerticalCornerPattern(SMAATexture2D edgesTex, inout float2 weights, float2 texcoord, float2 d) {
    #if SMAA_CORNER_ROUNDING < 100 || SMAA_FORCE_CORNER_DETECTION == 1
    float4 coords = mad(float4(0.0, d.x, 0.0, d.y),
                        SMAA_PIXEL_SIZE.xyxy, texcoord.xyxy);
    float2 e;
    e.r = SMAASampleLevelZeroOffset(edgesTex, coords.xy, int2( 1.0, 0.0)).g;
    bool left = abs(d.x) < abs(d.y);
    e.g = SMAASampleLevelZeroOffset(edgesTex, coords.xy, int2(-2.0, 0.0)).g;
    if (left) weights *= saturate(SMAA_CORNER_ROUNDING / 100.0 + 1.0 - e);

    e.r = SMAASampleLevelZeroOffset(edgesTex, coords.zw, int2( 1.0, 1.0)).g;
    e.g = SMAASampleLevelZeroOffset(edgesTex, coords.zw, int2(-2.0, 1.0)).g;
    if (!left) weights *= saturate(SMAA_CORNER_ROUNDING / 100.0 + 1.0 - e);
    #endif
}

//-----------------------------------------------------------------------------
// Blending Weight Calculation Pixel Shader (Second Pass)

float4 SMAABlendingWeightCalculationPS(float2 texcoord,
                                       float2 pixcoord,
                                       float4 offset[3],
                                       SMAATexture2D edgesTex, 
                                       SMAATexture2D areaTex, 
                                       SMAATexture2D searchTex) {
    float4 weights = 0.0;

    float2 e = SMAASample(edgesTex, texcoord).rg;

    [branch]
    if (e.g) { // Edge at north
        #if SMAA_MAX_SEARCH_STEPS_DIAG > 0 || SMAA_FORCE_DIAGONAL_DETECTION == 1
        // Diagonals have both north and west edges, so searching for them in
        // one of the boundaries is enough.
        weights.rg = SMAACalculateDiagWeights(edgesTex, areaTex, texcoord, e);

        // We give priority to diagonals, so if we find a diagonal we skip 
        // horizontal/vertical processing.
        [branch]
        if (dot(weights.rg, 1.0) == 0.0) {
        #endif

        float2 d;

        // Find the distance to the left:
        float2 coords;
        coords.x = SMAASearchXLeft(edgesTex, searchTex, offset[0].xy, offset[2].x);
        coords.y = offset[1].y; // offset[1].y = texcoord.y - 0.25 * SMAA_PIXEL_SIZE.y (@CROSSING_OFFSET)
        d.x = coords.x;

        // Now fetch the left crossing edges, two at a time using bilinear
        // filtering. Sampling at -0.25 (see @CROSSING_OFFSET) enables to
        // discern what value each edge has:
        float e1 = SMAASampleLevelZero(edgesTex, coords).r;

        // Find the distance to the right:
        coords.x = SMAASearchXRight(edgesTex, searchTex, offset[0].zw, offset[2].y);
        d.y = coords.x;

        // We want the distances to be in pixel units (doing this here allow to
        // better interleave arithmetic and memory accesses):
        d = d / SMAA_PIXEL_SIZE.x - pixcoord.x;

        // SMAAArea below needs a sqrt, as the areas texture is compressed 
        // quadratically:
        float2 sqrt_d = sqrt(abs(d));

        // Fetch the right crossing edges:
        float e2 = SMAASampleLevelZeroOffset(edgesTex, coords, int2(1, 0)).r;

        // Ok, we know how this pattern looks like, now it is time for getting
        // the actual area:
        weights.rg = SMAAArea(areaTex, sqrt_d, e1, e2);

        SMAADetectHorizontalCornerPattern(edgesTex, weights.rg, texcoord, d);

        #if SMAA_MAX_SEARCH_STEPS_DIAG > 0 || SMAA_FORCE_DIAGONAL_DETECTION == 1
        } else
            e.r = 0.0; // Skip vertical processing.
        #endif
    }

    [branch]
    if (e.r) { // Edge at west
        float2 d;
        
        // Find the distance to the top:
        float2 coords;
        coords.y = SMAASearchYUp(edgesTex, searchTex, offset[1].xy, offset[2].z);
        coords.x = offset[0].x; // offset[1].x = texcoord.x - 0.25 * SMAA_PIXEL_SIZE.x;
        d.x = coords.y;

        // Fetch the top crossing edges:
        float e1 = SMAASampleLevelZero(edgesTex, coords).g;

        // Find the distance to the bottom:
        coords.y = SMAASearchYDown(edgesTex, searchTex, offset[1].zw, offset[2].w);
        d.y = coords.y;

        // We want the distances to be in pixel units:
        d = d / SMAA_PIXEL_SIZE.y - pixcoord.y;

        // SMAAArea below needs a sqrt, as the areas texture is compressed 
        // quadratically:
        float2 sqrt_d = sqrt(abs(d));

        // Fetch the bottom crossing edges:
        float e2 = SMAASampleLevelZeroOffset(edgesTex, coords, int2(0, 1)).g;

        // Get the area for this direction:
        weights.ba = SMAAArea(areaTex, sqrt_d, e1, e2);

        SMAADetectVerticalCornerPattern(edgesTex, weights.ba, texcoord, d);
    }

    return weights;
}

//-----------------------------------------------------------------------------
// Neighborhood Blending Pixel Shader (Third Pass)

float4 SMAANeighborhoodBlendingPS(float2 texcoord,
                                  float4 offset[2],
                                  SMAATexture2D colorTex,
                                  SMAATexture2D blendTex) {
    // Fetch the blending weights for current pixel:
    float4 topLeft = SMAASample(blendTex, texcoord);
    float bottom = SMAASample(blendTex, offset[1].zw).g;
    float right = SMAASample(blendTex, offset[1].xy).a;
    float4 a = float4(topLeft.r, bottom, topLeft.b, right);

    // Is there any blending weight with a value greater than 0.0?
    [branch]
    if (dot(a, 1.0) < 1e-5)
        return SMAASampleLevelZero(colorTex, texcoord);
    else {
        float4 color = 0.0;

        // Up to 4 lines can be crossing a pixel (one through each edge). We
        // favor blending by choosing the line with the maximum weight for each
        // direction:
        float2 offset;
        offset.x = a.a > a.b? a.a : -a.b; // left vs. right 
        offset.y = a.g > a.r? a.g : -a.r; // top vs. bottom

        // Then we go in the direction that has the maximum weight:
        if (abs(offset.x) > abs(offset.y)) // horizontal vs. vertical
            offset.y = 0.0;
        else
            offset.x = 0.0;

        #if SMAA_HLSL_4 == 1 || SMAA_DIRECTX9_LINEAR_BLEND == 0
        // We exploit bilinear filtering to mix current pixel with the chosen
        // neighbor:
        texcoord += offset * SMAA_PIXEL_SIZE;
        return SMAASampleLevelZero(colorTex, texcoord);
        #else
        // Fetch the opposite color and lerp by hand:
        float4 C = SMAASampleLevelZero(colorTex, texcoord);
        texcoord += sign(offset) * SMAA_PIXEL_SIZE;
        float4 Cop = SMAASampleLevelZero(colorTex, texcoord);
        float s = abs(offset.x) > abs(offset.y)? abs(offset.x) : abs(offset.y);
        return lerp(C, Cop, s);
        #endif
    }
}

//-----------------------------------------------------------------------------



///////////////////
// RENDER PASSES //
///////////////////

/**
 * Choose your edge detection!
 */
 SMAAColorEdgeDetectionPS
technique ColorEdgeDetection {
    pass ColorEdgeDetection {
        SetVertexShader(CompileShader(vs_4_0, DX10_SMAAEdgeDetectionVS()));
        SetGeometryShader(NULL);
        SetPixelShader(CompileShader(PS_VERSION, DX10_SMAAColorEdgeDetectionPS(colorGammaTex)));

        SetDepthStencilState(DisableDepthReplaceStencil, 1);
        SetBlendState(NoBlending, float4(0.0f, 0.0f, 0.0f, 0.0f), 0xFFFFFFFF);
    }
}

technique t0 {

    pass p0 {

	CullMode = None;
	VertexShader = compile vs_3_0 FrameVS();
    PixelShader = compile ps_3_0 NormalAAPS();
    }
}