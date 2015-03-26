//-----------------------------------------
//	VertexTerrain
//-----------------------------------------

/// Vertex structs

struct VT_Input
{
    float2 Position : POSITION0;
	float2 EncNormal : TEXCOORD0;
};

struct VT_Output
{
    float4 Position : POSITION0;
	float4 Color : COLOR;
    float3 Depth : TEXCOORD1;
	float3 Normal : TEXCOORD2;
	float4 NewPosition : TEXCOORD3;
	float4 ViewPosition : TEXCOORD4;
    float3x3 TangentToWorld	: TEXCOORD5;
};

/// VertexShaders

const float epsilon = 0.000001f;

float3 decodeNormal (float2 encodedNormal)
{
    float2 p = encodedNormal;
    
    // Find z sign
    float zsign = sign (1.0 - abs (p.x) - abs (p.y));

    // Map outer triangles to center if encoded z is negative
    float isNegative = max (-zsign, 0.0);
    float2 pSign = sign (p);
    pSign = sign (pSign + float2 (0.5, 0.5));

    // Reflection: qr = q - 2 * n * (dot (q, n) - d) / dot (n, n)
    p -= isNegative * (dot (p, pSign) - 1.0) * pSign;

    // Convert square to unit circle
    // Add epsilon to avoid division by zero
    float r = abs (p.x) + abs (p.y);
    float d = length (p) + epsilon;
    float2 q = p * r / d;

    // Unproject unit circle to sphere
    float den = 2.0 / (dot (q, q) + 1.0);
    float3 v = float3(den * q, zsign * (den - 1.0));

    return v;
}

VT_Output VertexShaderTerrain(VT_Input input, uniform float yOffset = 0)
{
    VT_Output output;

	input.Position.y += yOffset;

	// First transform the position onto the screen
	float4 localPosition;
	localPosition.x = input.Position.x % meshSize;
	localPosition.y = input.Position.y * heightScale;
	localPosition.z = -(int)(input.Position.x / meshSize);
	localPosition.w = 1;

	float4 worldPos = mul(localPosition, World);
	float4 viewPos = mul(worldPos, View);

	output.Position = mul(viewPos, Projection);
	output.NewPosition = worldPos / 10.f;
	output.ViewPosition = mul(viewPos, Projection);

	// Pass the normal and depth
	float3 objNormal = decodeNormal(input.EncNormal);
	output.Normal = normalize(mul(objNormal, World));
	output.Depth.xyz = output.Position.zwz;

	// calculate tangent space to world space matrix using the world space tangent,
    // binormal, and normal as basis vectors.

	float3 c1 = cross(objNormal, float3(0, 0, 1));
	float3 c2 = cross(objNormal, float3(0, 1, 0));

	// Calculate tangent
	float3 tangent = (distance(c1, 0) > distance(c2, 0)) ? c1 : c2;
	float3 bitangent = cross(objNormal, tangent);

	output.TangentToWorld[0] = normalize(mul(mul(tangent, World), View));
    output.TangentToWorld[1] = normalize(mul(mul(bitangent, World), View));
    output.TangentToWorld[2] = normalize(mul(mul(objNormal, World), View));

	output.Color = 1;

    return output;
}