#include "UnityCG.cginc"
#include "Lighting.cginc"
#include "AutoLight.cginc"

float4 TransformWorldToHClip(float3 positionWS){
	return mul(UNITY_MATRIX_VP, float4(positionWS, 1.0));
}

struct VertexPositionInputs {
    float3 positionWS;
    float4 positionCS;
};
 
struct VertexNormalInputs {
    float3 normalWS;
};
 
VertexPositionInputs GetVertexPositionInputs(float3 positionOS) {
    VertexPositionInputs input;
    input.positionWS = mul(UNITY_MATRIX_M, float4(positionOS, 1.0)).xyz;
    input.positionCS = TransformWorldToHClip(input.positionWS);
    
    return input;
}
 
VertexNormalInputs GetVertexNormalInputs(float3 normalOS) {
    VertexNormalInputs tbn;
    tbn.normalWS = UnityObjectToWorldNormal(normalOS);
    return tbn;
}




struct Attributes {
	float3 positionOS : POSITION;
	float3 normalOS : NORMAL;
	float2 uv : TEXCOORD0;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct TessellationControlPoint {
	float3 positionOS : TEXCOORD0;
	float3 positionWS : INTERNALTESSPOS;
	float3 normalWS : NORMAL;
	float3 uv : TEXCOORD1;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

TessellationControlPoint Vertex(Attributes input){
	TessellationControlPoint output;

	UNITY_SETUP_INSTANCE_ID(input);
	UNITY_TRANSFER_INSTANCE_ID(input, output);

	VertexPositionInputs posnInputs = GetVertexPositionInputs(input.positionOS);
	VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS);
	
	output.positionOS = input.positionOS;
	output.positionWS = posnInputs.positionWS;
    output.normalWS = normalInputs.normalWS;
	
	output.uv = float3(input.uv, 0);
	return output;
}




[domain("tri")]
[outputcontrolpoints(3)]
[outputtopology("triangle_cw")]
[patchconstantfunc("PatchConstantFunction")]
[partitioning("fractional_even")]
TessellationControlPoint Hull(
	InputPatch<TessellationControlPoint, 3> patch,
	uint id : SV_OutputControlPointID
){
	return patch[id];		
}


struct TessellationFactors {
	float edge[3] : SV_TessFactor;
	float inside : SV_InsideTessFactor;
};

bool TriangleIsBelowClipPlane (
	float3 p0, float3 p1, float3 p2, int planeIndex, float bias
){
	float4 plane = unity_CameraWorldClipPlanes[planeIndex];
	return
		dot(float4(p0, 1), plane) < bias &&
		dot(float4(p1, 1), plane) < bias &&
		dot(float4(p2, 1), plane) < bias;
}
bool TriangleIsCulled (float3 p0, float3 p1, float3 p2, float bias){
	return TriangleIsBelowClipPlane(p0, p1, p2, 0, bias) ||
		   TriangleIsBelowClipPlane(p0, p1, p2, 1, bias) ||
		   TriangleIsBelowClipPlane(p0, p1, p2, 2, bias) ||
		   TriangleIsBelowClipPlane(p0, p1, p2, 3, bias);
}

float _TessellationEdgeLength;
uniform float _Amplitude;

float TessellationEdgeFactor (
	float3 p0, float3 p1
) {
	float edgeLength = distance(p0, p1);

	float3 edgeCenter = (p0 + p1) * 0.5;
	float viewDistance = distance(edgeCenter, _WorldSpaceCameraPos);

	return edgeLength * _ScreenParams.y / (_TessellationEdgeLength * viewDistance);

}


TessellationFactors PatchConstantFunction(
	InputPatch<TessellationControlPoint, 3> patch)
{
	UNITY_SETUP_INSTANCE_ID(patch[0]);

	float3 p0 = patch[0].positionWS;
	float3 p1 = patch[1].positionWS;
	float3 p2 = patch[2].positionWS;


	TessellationFactors f;
	float bias = -1 * _Amplitude;
	if (TriangleIsCulled(p0, p1, p2, bias)){
		f.edge[0] = f.edge[1] = f.edge[2] = f.inside = 0;
	}

	else{
		f.edge[0] = TessellationEdgeFactor(p1, p2);
		f.edge[1] = TessellationEdgeFactor(p2, p0);
		f.edge[2] = TessellationEdgeFactor(p0, p1);
		f.inside = 
			(TessellationEdgeFactor(p1, p2) +
			 TessellationEdgeFactor(p2, p0) +
			 TessellationEdgeFactor(p0, p1)) * (1 / 3.0);
	}
	return f;
}


uniform sampler2D _HeightMap;


#define BARYCENTRIC_INTERPOLATE(fieldName) \
		patch[0].fieldName * barycentricCoordinates.x + \
		patch[1].fieldName * barycentricCoordinates.y + \
		patch[2].fieldName * barycentricCoordinates.z