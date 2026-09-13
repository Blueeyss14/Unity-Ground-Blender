Shader "Ground Blender URP"
{
    Properties
    {
        [Header(Object Settings)]
        _BaseMap ("Object Texture (Albedo)", 2D) = "white" {}
        _BaseColor ("Object Color Tint", Color) = (1,1,1,1)
        [Normal] _BumpMap ("Object Normal Map", 2D) = "bump" {}
        _BumpScale ("Object Normal Scale", Float) = 1.0
        _Smoothness ("Object Smoothness", Range(0, 1)) = 0.5
        _Metallic ("Object Metallic", Range(0, 1)) = 0.0

        [HideInInspector] _HasGroundTexture ("Has Ground Texture", Float) = 0
        [HideInInspector] _GroundAlbedoMap ("Ground Texture (Albedo)", 2D) = "white" {}
        [HideInInspector] _GroundColor ("Ground Color Tint", Color) = (1,1,1,1)
        [HideInInspector] _GroundBumpMap ("Ground Normal Map", 2D) = "bump" {}
        [HideInInspector] _GroundBumpScale ("Ground Normal Scale", Float) = 1.0
        [HideInInspector] _GroundTiling ("Ground Texture Scale / Tiling", Float) = 0.1
        [HideInInspector] _GroundSmoothness ("Ground Smoothness", Range(0, 1)) = 0.2

        [Header(Blending Parameters)]
        _BlendDistance ("Blend Distance (Height)", Range(0.01, 5.0)) = 0.8
        _BlendContrast ("Blend Falloff / Softness", Range(0.1, 5.0)) = 1.5
        _NormalBlendStrength ("Normal Blend Strength", Range(0, 1)) = 0.8
        [Toggle(_TRIPLANAR_GROUND)] _UseTriplanarGround ("Use Triplanar Mapping for Ground", Float) = 1
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Geometry+500"
        }
        LOD 300

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            ZWrite On
            Cull Back

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma shader_feature_local _TRIPLANAR_GROUND

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile _ LIGHTMAP_SH_MIXING
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile_fragment _ DYNAMICLIGHTMAP_ON

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
                float4 tangentOS    : TANGENT;
                float2 uv           : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS   : SV_POSITION;
                float3 positionWS   : TEXCOORD0;
                float3 normalWS     : TEXCOORD1;
                float4 tangentWS    : TEXCOORD2;
                float2 uv           : TEXCOORD3;
                float4 screenPos    : TEXCOORD4;
            };

            TEXTURE2D(_BaseMap);           SAMPLER(sampler_BaseMap);
            TEXTURE2D(_BumpMap);           SAMPLER(sampler_BumpMap);
            TEXTURE2D(_GroundAlbedoMap);   SAMPLER(sampler_GroundAlbedoMap);
            TEXTURE2D(_GroundBumpMap);     SAMPLER(sampler_GroundBumpMap);

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                float4 _BaseColor;
                float _BumpScale;
                float _Smoothness;
                float _Metallic;

                float _HasGroundTexture;
                float4 _GroundColor;
                float _GroundBumpScale;
                float _GroundTiling;
                float _GroundSmoothness;

                float _BlendDistance;
                float _BlendContrast;
                float _NormalBlendStrength;
            CBUFFER_END

            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

                output.positionCS = vertexInput.positionCS;
                output.positionWS = vertexInput.positionWS;
                output.normalWS = normalInput.normalWS;
                output.tangentWS = float4(normalInput.tangentWS, input.tangentOS.w);
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
                output.screenPos = ComputeScreenPos(vertexInput.positionCS);

                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                float2 screenUV = input.screenPos.xy / input.screenPos.w;
                float rawDepth = SampleSceneDepth(screenUV);

                float backgroundLinearDepth = LinearEyeDepth(rawDepth, _ZBufferParams);
                float surfaceLinearDepth = input.screenPos.w;
                float depthDiff = max(0.0, backgroundLinearDepth - surfaceLinearDepth);

                float blendFactor = saturate(depthDiff / max(0.001, _BlendDistance));
                blendFactor = pow(blendFactor, max(0.01, _BlendContrast));

                if (_HasGroundTexture < 0.5)
                {
                    blendFactor = 1.0;
                }

                half4 objectAlbedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv) * _BaseColor;
                half3 objectNormalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, input.uv), _BumpScale);

                float3 bitangent = cross(input.normalWS, input.tangentWS.xyz) * input.tangentWS.w;
                float3x3 tbn = float3x3(input.tangentWS.xyz, bitangent, input.normalWS);
                float3 objectNormalWS = normalize(mul(objectNormalTS, tbn));

                half4 groundAlbedo = half4(1, 1, 1, 1);
                half3 groundNormalTS = half3(0, 0, 1);

                if (_HasGroundTexture >= 0.5)
                {
                    #if defined(_TRIPLANAR_GROUND)
                        float3 blendWeights = pow(abs(input.normalWS), 4.0);
                        blendWeights /= max(0.00001, blendWeights.x + blendWeights.y + blendWeights.z);

                        float2 uvX = input.positionWS.zy * _GroundTiling;
                        float2 uvY = input.positionWS.xz * _GroundTiling;
                        float2 uvZ = input.positionWS.xy * _GroundTiling;

                        half4 gX = SAMPLE_TEXTURE2D(_GroundAlbedoMap, sampler_GroundAlbedoMap, uvX);
                        half4 gY = SAMPLE_TEXTURE2D(_GroundAlbedoMap, sampler_GroundAlbedoMap, uvY);
                        half4 gZ = SAMPLE_TEXTURE2D(_GroundAlbedoMap, sampler_GroundAlbedoMap, uvZ);

                        groundAlbedo = (gX * blendWeights.x + gY * blendWeights.y + gZ * blendWeights.z) * _GroundColor;

                        half3 nX = UnpackNormalScale(SAMPLE_TEXTURE2D(_GroundBumpMap, sampler_GroundBumpMap, uvX), _GroundBumpScale);
                        half3 nY = UnpackNormalScale(SAMPLE_TEXTURE2D(_GroundBumpMap, sampler_GroundBumpMap, uvY), _GroundBumpScale);
                        half3 nZ = UnpackNormalScale(SAMPLE_TEXTURE2D(_GroundBumpMap, sampler_GroundBumpMap, uvZ), _GroundBumpScale);
                        groundNormalTS = nX * blendWeights.x + nY * blendWeights.y + nZ * blendWeights.z;
                    #else
                        float2 groundUV = input.positionWS.xz * _GroundTiling;
                        groundAlbedo = SAMPLE_TEXTURE2D(_GroundAlbedoMap, sampler_GroundAlbedoMap, groundUV) * _GroundColor;
                        groundNormalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_GroundBumpMap, sampler_GroundBumpMap, groundUV), _GroundBumpScale);
                    #endif
                }

                float3 groundNormalWS = normalize(float3(groundNormalTS.x, max(0.1, groundNormalTS.z), groundNormalTS.y));

                half4 finalAlbedo = lerp(groundAlbedo, objectAlbedo, blendFactor);
                half finalSmoothness = lerp(_GroundSmoothness, _Smoothness, blendFactor);
                half finalMetallic = lerp(0.0, _Metallic, blendFactor);

                float3 targetGroundNormal = lerp(float3(0, 1, 0), groundNormalWS, _NormalBlendStrength);
                float3 finalNormalWS = normalize(lerp(targetGroundNormal, objectNormalWS, blendFactor));

                InputData inputData = (InputData)0;
                inputData.positionWS = input.positionWS;
                inputData.normalWS = finalNormalWS;
                inputData.viewDirectionWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
                inputData.shadowCoord = TransformWorldToShadowCoord(input.positionWS);
                inputData.normalizedScreenSpaceUV = screenUV;

                #if defined(DYNAMICLIGHTMAP_ON) || defined(LIGHTMAP_ON)
                    inputData.bakedGI = SampleLightmap(input.uv, input.uv, inputData.normalWS);
                #else
                    inputData.bakedGI = SampleSH(inputData.normalWS);
                #endif

                SurfaceData surfaceData = (SurfaceData)0;
                surfaceData.albedo = finalAlbedo.rgb;
                surfaceData.alpha = finalAlbedo.a;
                surfaceData.metallic = _Metallic;
                surfaceData.smoothness = _Smoothness;
                surfaceData.normalTS = float3(0, 0, 1);
                surfaceData.occlusion = 1.0;

                half4 color = UniversalFragmentPBR(inputData, surfaceData);
                color.a = 1.0;
                return color;
            }
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull Back

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
            };

            struct Varyings
            {
                float4 positionCS   : SV_POSITION;
            };

            float3 _LightDirection;

            Varyings vert(Attributes input)
            {
                Varyings output;
                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
                output.positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, _LightDirection));
                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                return 0;
            }
            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }

            ZWrite On
            ColorMask R
            Cull Back

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION;
            };

            struct Varyings
            {
                float4 positionCS   : SV_POSITION;
            };

            Varyings vert(Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                return input.positionCS.z;
            }
            ENDHLSL
        }
    }
    FallBack "Hidden/Universal Render Pipeline/FallbackError"
    CustomEditor "GroundBlendShaderGUI"
}
