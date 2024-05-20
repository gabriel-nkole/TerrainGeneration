struct Interpolators {
	float4 vertex : TEXCOORD0;
	float3 positionWS : TEXCOORD1;
	float4 pos : SV_POSITION;
	float3 normalWS : TEXCOORD2;
	float2 uv : TEXCOORD3;
	LIGHTING_COORDS(4, 5)
};


[domain("tri")]
Interpolators Domain(
	TessellationFactors factors,
	OutputPatch<TessellationControlPoint, 3> patch,
	float3 barycentricCoordinates : SV_DomainLocation
){
	Interpolators v;

	UNITY_SETUP_INSTANCE_ID(patch[0]);
	UNITY_TRANSFER_INSTANCE_ID(patch[0], v);
	UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(v);

	v.vertex = float4(BARYCENTRIC_INTERPOLATE(positionOS), 1);
	float3 positionWS = BARYCENTRIC_INTERPOLATE(positionWS);
	float3 normalWS = normalize(BARYCENTRIC_INTERPOLATE(normalWS));
	
	float3 uv = BARYCENTRIC_INTERPOLATE(uv);
	float height = tex2Dlod(_HeightMap, float4(uv.xy, 0, 0)).x;
    height *= _Amplitude;
	positionWS += normalWS * height;

	v.positionWS = positionWS;
	v.pos = TransformWorldToHClip(positionWS);
	v.normalWS = normalWS;
	v.uv = uv.xy;

	TRANSFER_VERTEX_TO_FRAGMENT(v)
	return v;
}

float3 _AmbientColor;
float3 _SurfaceColor;
float _Gloss;

float4 Fragment (Interpolators i) : SV_Target {
	UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

	//calculate normal uthrough central difference
	float sampleDist = 0.02;
	float y_x1 = tex2D(_HeightMap, float2(i.uv.x-sampleDist, i.uv.y)).x;
	float y_x2 = tex2D(_HeightMap, float2(i.uv.x+sampleDist, i.uv.y)).x;
	float y_z1 = tex2D(_HeightMap, float2(i.uv.x, i.uv.y-sampleDist)).x;
	float y_z2 = tex2D(_HeightMap, float2(i.uv.x, i.uv.y+sampleDist)).x;

	//dy_dx <-> dy/dx
	float dy_dx = (y_x2-y_x1) / (sampleDist * 2) * _Amplitude;
	float dy_dz = (y_z2-y_z1) / (sampleDist * 2) * _Amplitude;

	float3 tangent = float3(1, dy_dx, 0);
	float3 binormal = float3(0, dy_dz, 1);
	float3 N = normalize(cross(binormal, tangent));


    float3 L = normalize(UnityWorldSpaceLightDir(i.positionWS));
    float attenuation = LIGHT_ATTENUATION(i);
	


    float3 col = 0;

	//BLINN-PHONG
    //Lambertion diffuse
	//col += saturate(dot(N, L)) * _SurfaceColor;
	
	//Half Lambertion Diffuse
	col += (dot(N, L) * 0.5 + 0.5) * _SurfaceColor;
	
    //Specular 
    float3 R = reflect(-L, N);
    float3 V = normalize(_WorldSpaceCameraPos - i.positionWS);
    float specularExponent = exp2(_Gloss * 11) + 2; 
    col += pow(saturate(dot(R, V)), specularExponent) * _Gloss;
	
	//Light properties
    col *= _LightColor0.xyz * attenuation;


	//Ambient
    #ifdef IS_IN_BASE_PASS
        col += _AmbientColor;
    #endif

    return float4(col, 1);
}