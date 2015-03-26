//-----------------------------------------
// TerrainConstants
//-----------------------------------------

float4x4 World;
float4x4 View;
float4x4 Projection;
float4x4 inverseView;

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

texture Texture, steepTexture;
sampler baseSampler : register(s0) = sampler_state
{
    Texture = <Texture>;
	Filter = MIN_MAG_MIP_LINEAR;
	AddressU = Wrap;
	AddressV = Wrap;
};

sampler baseSteepSampler : register(s1) = sampler_state
{
    Texture = <steepTexture>;
	Filter = MIN_MAG_MIP_LINEAR;
	AddressU = Wrap;
	AddressV = Wrap;
};

texture heightMapTexture;
sampler heightSampler : register(s2) = sampler_state
{
    Texture = <heightMapTexture>;
	Filter = MIN_MAG_MIP_LINEAR;
	AddressU = Wrap;
	AddressV = Wrap;
};

/// Normal map textures

texture NormalMap, steepNormalMap;
sampler normalMapSampler : register(s3) = sampler_state
{
    Texture = <NormalMap>;
	Filter = MIN_MAG_MIP_LINEAR;
	AddressU = Wrap;
	AddressV = Wrap;
};

sampler steepNormalMapSampler : register(s4) = sampler_state
{
    Texture = <steepNormalMap>;
	Filter = MIN_MAG_MIP_LINEAR;
	AddressU = Wrap;
	AddressV = Wrap;
};

/// Blend textures

texture blendTexture1;
sampler blendSampler1 = sampler_state
{
    Texture = <blendTexture1>;
	Filter = MIN_MAG_MIP_LINEAR;
	AddressU = Wrap;
	AddressV = Wrap;
};