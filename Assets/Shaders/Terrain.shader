Shader "Custom/TessellationShader" {
    Properties {
        _TessellationEdgeLength("Tessellation Edge Length", Range(5, 100)) = 50

        _AmbientColor ("Ambient Color", Color) = (0, 0, 0, 0)
        _SurfaceColor ("Surface Color", Color) = (0, 0, 0, 0)
        _Gloss ("Gloss", Range(0,1)) = 0.7
    }
    SubShader {
        Tags { 
            "RenderType"="Opaque"
            "Queue"="Geometry"
        }
        Cull Off
        Pass {
            Tags { "LightMode"="ForwardBase" }
            CGPROGRAM
            #pragma target 5.0
            #define IS_IN_BASE_PASS
            #pragma vertex Vertex
            #pragma hull Hull
            #pragma domain Domain addshadow
            #pragma fragment Fragment

            #pragma multi_compile_fwdbase

            #include "Tessellation.cginc"
            #include "Light.cginc"
            ENDCG
        }

        Pass {
            Tags { "LightMode"="ForwardAdd" }
            Blend One One
            CGPROGRAM
            #pragma target 5.0
            #pragma vertex Vertex
            #pragma hull Hull
            #pragma domain Domain addshadow
            #pragma fragment Fragment
        
            #pragma multi_compile_fwdadd_fullshadows
        
            #include "Tessellation.cginc"
            #include "Light.cginc"
            ENDCG
        }

        Pass {
            Tags {"LightMode"="ShadowCaster"}
        
            CGPROGRAM
            #pragma target 5.0
            #pragma vertex Vertex
            #pragma hull Hull
            #pragma domain Domain
            #pragma fragment Fragment
            #pragma multi_compile_shadowcaster
            #include "UnityCG.cginc"
            #include "Tessellation.cginc"

            struct Interpolators {
	            float3 positionWS : TEXCOORD0;
	            float4 pos : SV_POSITION;
	            float3 normalWS : TEXCOORD1;
	            float2 uv : TEXCOORD2;
                float3 vec : TEXCOORD3;
            };
            
            [domain("tri")]
            Interpolators Domain(
	            TessellationFactors factors,
	            OutputPatch<TessellationControlPoint, 3> patch,
	            float3 barycentricCoordinates : SV_DomainLocation
            ){
	            Interpolators output;

	            UNITY_SETUP_INSTANCE_ID(patch[0]);
	            UNITY_TRANSFER_INSTANCE_ID(patch[0], output);
	            UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
                
                float4 positionOS = float4(BARYCENTRIC_INTERPOLATE(positionOS), 1);
	            float3 positionWS = BARYCENTRIC_INTERPOLATE(positionWS);
	            float3 normalWS = normalize(BARYCENTRIC_INTERPOLATE(normalWS));
	            
	            float3 uv = BARYCENTRIC_INTERPOLATE(uv);
	            float height = tex2Dlod(_HeightMap, float4(uv.xy, 0, 0)).x;
                height *= _Amplitude;
	            positionWS += normalWS * height;
                
	            output.positionWS = positionWS;
	            output.pos = TransformWorldToHClip(positionWS);
	            output.normalWS = normalWS;
	            output.uv = uv.xy;

                float4 opos = UnityClipSpaceShadowCasterPos(positionOS, normalWS);
                output.vec = UnityApplyLinearShadowBias(opos);
	            return output;
            }
        

            float4 Fragment(Interpolators i) : SV_Target{
                return UnityEncodeCubeShadowDepth ((length(i.vec) + unity_LightShadowBias.x) * _LightPositionRange.w);
            }
            ENDCG
        }
    }
}
