Shader "Ground Blender HDRP"
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

        [HideInInspector] _HasTerrainData ("Has Terrain Data", Float) = 0
        [HideInInspector] _TerrainControl ("Terrain Control", 2D) = "black" {}
        [HideInInspector] _TerrainSplat0 ("Terrain Splat 0", 2D) = "white" {}
        [HideInInspector] _TerrainSplat1 ("Terrain Splat 1", 2D) = "white" {}
        [HideInInspector] _TerrainSplat2 ("Terrain Splat 2", 2D) = "white" {}
        [HideInInspector] _TerrainSplat3 ("Terrain Splat 3", 2D) = "white" {}
        [HideInInspector] _TerrainNormal0 ("Terrain Normal 0", 2D) = "bump" {}
        [HideInInspector] _TerrainNormal1 ("Terrain Normal 1", 2D) = "bump" {}
        [HideInInspector] _TerrainNormal2 ("Terrain Normal 2", 2D) = "bump" {}
        [HideInInspector] _TerrainNormal3 ("Terrain Normal 3", 2D) = "bump" {}
        [HideInInspector] _TerrainHeightmap ("Terrain Heightmap", 2D) = "black" {}
        [HideInInspector] _TerrainHeightScaleHDRP ("Terrain Height Scale", Float) = 0

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
            "RenderPipeline" = "HDRenderPipeline"
            "RenderType" = "HDLitShader"
            "Queue" = "Geometry"
        }

        HLSLINCLUDE
        #pragma target 4.5
        #pragma only_renderers d3d11 playstation xboxone xboxseries vulkan metal switch
        ENDHLSL

        Pass
        {
            Name "ForwardOnly"
            Tags { "LightMode" = "ForwardOnly" }

            ZWrite On
            ZTest LEqual
            Cull Back

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag

            #pragma shader_feature_local _TRIPLANAR_GROUND

            #pragma multi_compile _ DEBUG_DISPLAY
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma multi_compile _ USE_LEGACY_LIGHTMAPS
            #pragma multi_compile_fragment _ SHADOWS_SHADOWMASK
            #pragma multi_compile_fragment _ PROBE_VOLUMES_L1 PROBE_VOLUMES_L2
            #pragma multi_compile_fragment SCREEN_SPACE_SHADOWS_OFF SCREEN_SPACE_SHADOWS_ON
            #pragma multi_compile_fragment DECALS_OFF DECALS_3RT DECALS_4RT
            #pragma multi_compile_fragment _ DECAL_SURFACE_GRADIENT
            #pragma multi_compile_fragment PUNCTUAL_SHADOW_LOW PUNCTUAL_SHADOW_MEDIUM PUNCTUAL_SHADOW_HIGH
            #pragma multi_compile_fragment DIRECTIONAL_SHADOW_LOW DIRECTIONAL_SHADOW_MEDIUM DIRECTIONAL_SHADOW_HIGH
            #pragma multi_compile_fragment AREA_SHADOW_MEDIUM AREA_SHADOW_HIGH
            #pragma multi_compile_fragment USE_FPTL_LIGHTLIST USE_CLUSTERED_LIGHTLIST

            #define PREFER_HALF 0
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShaderVariables.hlsl"
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/ShaderPass/FragInputs.hlsl"
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/ShaderPass/ShaderPass.cs.hlsl"

            #ifndef SHADER_STAGE_FRAGMENT
            #define SHADOW_LOW
            #ifndef USE_FPTL_LIGHTLIST
            #define USE_FPTL_LIGHTLIST
            #endif
            #endif

            #define SHADERPASS SHADERPASS_FORWARD
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/Material.hlsl"
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Lighting/Lighting.hlsl"

            #ifdef DEBUG_DISPLAY
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Debug/DebugDisplay.hlsl"
            #endif

            #define HAS_LIGHTLOOP
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Lighting/LightLoop/LightLoopDef.hlsl"
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/Lit/Lit.hlsl"
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Lighting/LightLoop/LightLoop.hlsl"

            struct Attributes
            {
                float3 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
                float4 tangentOS    : TANGENT;
                float2 uv           : TEXCOORD0;
                float2 uv1          : TEXCOORD1;
                float2 uv2          : TEXCOORD2;
            };

            struct Varyings
            {
                float4 positionCS   : SV_POSITION;
                float3 positionRWS  : TEXCOORD0;
                float3 normalWS     : TEXCOORD1;
                float4 tangentWS    : TEXCOORD2;
                float2 uv           : TEXCOORD3;
                float4 uv1          : TEXCOORD4;
                float4 uv2          : TEXCOORD5;
            };

            TEXTURE2D(_BaseMap);           SAMPLER(sampler_BaseMap);
            TEXTURE2D(_BumpMap);           SAMPLER(sampler_BumpMap);
            TEXTURE2D(_GroundAlbedoMap);
            TEXTURE2D(_GroundBumpMap);

            TEXTURE2D(_TerrainControl);
            TEXTURE2D(_TerrainSplat0);
            TEXTURE2D(_TerrainSplat1);
            TEXTURE2D(_TerrainSplat2);
            TEXTURE2D(_TerrainSplat3);
            TEXTURE2D(_TerrainNormal0);
            TEXTURE2D(_TerrainNormal1);
            TEXTURE2D(_TerrainNormal2);
            TEXTURE2D(_TerrainNormal3);
            TEXTURE2D(_TerrainHeightmap);

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

                float _HasTerrainData;
                float _TerrainHeightScaleHDRP;
            CBUFFER_END

            float4 _TerrainPositionHDRP;
            float4 _TerrainSizeHDRP;
            float4 _TerrainTileSizeHDRP0;
            float4 _TerrainTileSizeHDRP1;
            float4 _TerrainTileSizeHDRP2;
            float4 _TerrainTileSizeHDRP3;

            float4x4 _GroundWorldToLocalHDRP;
            float4 _GroundUGradHDRP;
            float4 _GroundVGradHDRP;
            float4 _GroundSTHDRP;
            float4 _GroundTangentWSHDRP;
            float4 _GroundBitangentWSHDRP;
            float4 _GroundNormalWSHDRP;
            float4 _GroundPositionWSHDRP;
            float _HasGroundObjectHDRP;


            Varyings Vert(Attributes input)
            {
                Varyings output = (Varyings)0;

                float3 positionRWS = TransformObjectToWorld(input.positionOS);
                output.positionCS = TransformWorldToHClip(positionRWS);
                output.positionRWS = positionRWS;
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                output.tangentWS = float4(TransformObjectToWorldDir(input.tangentOS.xyz), input.tangentOS.w * GetOddNegativeScale());
                output.uv = input.uv * _BaseMap_ST.xy + _BaseMap_ST.zw;
                output.uv1 = float4(input.uv1, 0, 0);
                output.uv2 = float4(input.uv2, 0, 0);
                return output;
            }

            half3 UnpackGroundNormal(half4 texSample, float scale)
            {
                if (dot(texSample.rgb, 1.0) < 0.001 && texSample.a < 0.001)
                {
                    return half3(0, 0, 1);
                }
                return UnpackNormalScale(texSample, scale);
            }

            float2 GroundObjectUV(float3 posWS)
            {
                float3 l = mul(_GroundWorldToLocalHDRP, float4(posWS, 1.0)).xyz;
                float2 uv = float2(dot(_GroundUGradHDRP.xyz, l) + _GroundUGradHDRP.w,
                                   dot(_GroundVGradHDRP.xyz, l) + _GroundVGradHDRP.w);
                return uv * _GroundSTHDRP.xy + _GroundSTHDRP.zw;
            }


            float4 Frag(Varyings input) : SV_Target
            {
                input.normalWS = normalize(input.normalWS);

                float3 positionRWS = input.positionRWS;
                float3 positionAWS = GetAbsolutePositionWS(positionRWS);

                float2 positionNDC = input.positionCS.xy * _ScreenSize.zw;
                float rawDepth = LoadCameraDepth(input.positionCS.xy);
                float3 sceneAWS = GetAbsolutePositionWS(ComputeWorldSpacePosition(positionNDC, rawDepth, UNITY_MATRIX_I_VP));

                #if UNITY_REVERSED_Z
                    bool noSceneBehind = rawDepth < 0.00001;
                #else
                    bool noSceneBehind = rawDepth > 0.99999;
                #endif

                float heightAboveGround = _BlendDistance;

                if (_HasTerrainData >= 0.5)
                {
                    float2 tUV = saturate((positionAWS.xz - _TerrainPositionHDRP.xz) / max(float2(0.001, 0.001), _TerrainSizeHDRP.xz));
                    float hmSample = UnpackHeightmap(SAMPLE_TEXTURE2D_LOD(_TerrainHeightmap, sampler_BaseMap, tUV, 0));
                    float hScale = _TerrainHeightScaleHDRP > 0.01 ? _TerrainHeightScaleHDRP : (_TerrainSizeHDRP.y * 2.0);
                    float terrainH = _TerrainPositionHDRP.y + hmSample * hScale;

                    heightAboveGround = max(0.0, positionAWS.y - terrainH);
                }
                else if (_HasGroundObjectHDRP >= 0.5)
                {
                    float hFromObj = dot(positionAWS - _GroundPositionWSHDRP.xyz, _GroundNormalWSHDRP.xyz);
                    heightAboveGround = max(0.0, hFromObj);
                }
                else if (!noSceneBehind)
                {
                    float3 dWSdx = ddx(sceneAWS);
                    float3 dWSdy = ddy(sceneAWS);
                    float3 sceneNormalWS = normalize(cross(dWSdy, dWSdx));

                    bool isWall = abs(sceneNormalWS.y) < 0.25;
                    bool isHigher = sceneAWS.y > (positionAWS.y + 0.05);
                    bool isTooFar = distance(positionAWS, sceneAWS) > max(_BlendDistance * 2.5, 2.0);

                    if (!isWall && !isHigher && !isTooFar)
                    {
                        heightAboveGround = max(0.0, positionAWS.y - sceneAWS.y);
                    }
                    else
                    {
                        heightAboveGround = _BlendDistance;
                    }
                }

                float foldH = min(heightAboveGround, _BlendDistance);
                float2 nXZ = input.normalWS.xz;
                float2 groundXZ = positionAWS.xz + nXZ * foldH / max(dot(nXZ, nXZ), 0.04);

                if (_HasTerrainData >= 0.5)
                {
                    float2 tUVFold = saturate((groundXZ - _TerrainPositionHDRP.xz) / max(float2(0.001, 0.001), _TerrainSizeHDRP.xz));
                    float hmFold = UnpackHeightmap(SAMPLE_TEXTURE2D_LOD(_TerrainHeightmap, sampler_BaseMap, tUVFold, 0));
                    float hScale = _TerrainHeightScaleHDRP > 0.01 ? _TerrainHeightScaleHDRP : (_TerrainSizeHDRP.y * 2.0);
                    float terrainHFold = _TerrainPositionHDRP.y + hmFold * hScale;
                    heightAboveGround = max(0.0, positionAWS.y - terrainHFold);
                }

                float blendFactor = saturate(heightAboveGround / max(0.001, _BlendDistance));
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
                    if (_HasTerrainData >= 0.5)
                    {
                        float2 terrainUV = saturate((groundXZ - _TerrainPositionHDRP.xz) / max(float2(0.001, 0.001), _TerrainSizeHDRP.xz));

                        float2 tGroundXZ = groundXZ - _TerrainPositionHDRP.xz;
                        float2 tPosZY    = positionAWS.zy - _TerrainPositionHDRP.zy;
                        float2 tPosXY    = positionAWS.xy - _TerrainPositionHDRP.xy;

                        half4 splatControl = SAMPLE_TEXTURE2D(_TerrainControl, sampler_BaseMap, terrainUV);
                        half totalSplatWeight = splatControl.r + splatControl.g + splatControl.b + splatControl.a;
                        if (totalSplatWeight > 0.001)
                        {
                            splatControl /= totalSplatWeight;
                        }
                        else
                        {
                            splatControl = half4(1, 0, 0, 0);
                        }

                        #if defined(_TRIPLANAR_GROUND)
                            float3 blendWeights = pow(abs(input.normalWS), 4.0);
                            blendWeights = lerp(float3(0.0, 1.0, 0.0), blendWeights, blendFactor);
                            blendWeights /= max(0.00001, blendWeights.x + blendWeights.y + blendWeights.z);

                            float4 ts0 = _TerrainTileSizeHDRP0.x > 0.0001 ? _TerrainTileSizeHDRP0 : float4(0.1, 0.1, 0, 0);
                            float4 ts1 = _TerrainTileSizeHDRP1.x > 0.0001 ? _TerrainTileSizeHDRP1 : ts0;
                            float4 ts2 = _TerrainTileSizeHDRP2.x > 0.0001 ? _TerrainTileSizeHDRP2 : ts0;
                            float4 ts3 = _TerrainTileSizeHDRP3.x > 0.0001 ? _TerrainTileSizeHDRP3 : ts0;

                            float2 uv0_X = tPosZY * ts0.xy + ts0.zw;
                            float2 uv1_X = tPosZY * ts1.xy + ts1.zw;
                            float2 uv2_X = tPosZY * ts2.xy + ts2.zw;
                            float2 uv3_X = tPosZY * ts3.xy + ts3.zw;

                            float2 uv0_Y = tGroundXZ * ts0.xy + ts0.zw;
                            float2 uv1_Y = tGroundXZ * ts1.xy + ts1.zw;
                            float2 uv2_Y = tGroundXZ * ts2.xy + ts2.zw;
                            float2 uv3_Y = tGroundXZ * ts3.xy + ts3.zw;

                            float2 uv0_Z = tPosXY * ts0.xy + ts0.zw;
                            float2 uv1_Z = tPosXY * ts1.xy + ts1.zw;
                            float2 uv2_Z = tPosXY * ts2.xy + ts2.zw;
                            float2 uv3_Z = tPosXY * ts3.xy + ts3.zw;

                            half4 c0_X = SAMPLE_TEXTURE2D(_TerrainSplat0, sampler_BaseMap, uv0_X);
                            half4 c1_X = SAMPLE_TEXTURE2D(_TerrainSplat1, sampler_BaseMap, uv1_X);
                            half4 c2_X = SAMPLE_TEXTURE2D(_TerrainSplat2, sampler_BaseMap, uv2_X);
                            half4 c3_X = SAMPLE_TEXTURE2D(_TerrainSplat3, sampler_BaseMap, uv3_X);
                            half4 colX = c0_X * splatControl.r + c1_X * splatControl.g + c2_X * splatControl.b + c3_X * splatControl.a;

                            half4 c0_Y = SAMPLE_TEXTURE2D(_TerrainSplat0, sampler_BaseMap, uv0_Y);
                            half4 c1_Y = SAMPLE_TEXTURE2D(_TerrainSplat1, sampler_BaseMap, uv1_Y);
                            half4 c2_Y = SAMPLE_TEXTURE2D(_TerrainSplat2, sampler_BaseMap, uv2_Y);
                            half4 c3_Y = SAMPLE_TEXTURE2D(_TerrainSplat3, sampler_BaseMap, uv3_Y);
                            half4 colY = c0_Y * splatControl.r + c1_Y * splatControl.g + c2_Y * splatControl.b + c3_Y * splatControl.a;

                            half4 c0_Z = SAMPLE_TEXTURE2D(_TerrainSplat0, sampler_BaseMap, uv0_Z);
                            half4 c1_Z = SAMPLE_TEXTURE2D(_TerrainSplat1, sampler_BaseMap, uv1_Z);
                            half4 c2_Z = SAMPLE_TEXTURE2D(_TerrainSplat2, sampler_BaseMap, uv2_Z);
                            half4 c3_Z = SAMPLE_TEXTURE2D(_TerrainSplat3, sampler_BaseMap, uv3_Z);
                            half4 colZ = c0_Z * splatControl.r + c1_Z * splatControl.g + c2_Z * splatControl.b + c3_Z * splatControl.a;

                            half4 groundTint = (_GroundColor.r + _GroundColor.g + _GroundColor.b < 0.01) ? half4(1,1,1,1) : _GroundColor;
                            groundAlbedo = (colX * blendWeights.x + colY * blendWeights.y + colZ * blendWeights.z) * groundTint;

                            half3 n0_X = UnpackGroundNormal(SAMPLE_TEXTURE2D(_TerrainNormal0, sampler_BumpMap, uv0_X), _GroundBumpScale);
                            half3 n1_X = UnpackGroundNormal(SAMPLE_TEXTURE2D(_TerrainNormal1, sampler_BumpMap, uv1_X), _GroundBumpScale);
                            half3 n2_X = UnpackGroundNormal(SAMPLE_TEXTURE2D(_TerrainNormal2, sampler_BumpMap, uv2_X), _GroundBumpScale);
                            half3 n3_X = UnpackGroundNormal(SAMPLE_TEXTURE2D(_TerrainNormal3, sampler_BumpMap, uv3_X), _GroundBumpScale);
                            half3 nX = n0_X * splatControl.r + n1_X * splatControl.g + n2_X * splatControl.b + n3_X * splatControl.a;

                            half3 n0_Y = UnpackGroundNormal(SAMPLE_TEXTURE2D(_TerrainNormal0, sampler_BumpMap, uv0_Y), _GroundBumpScale);
                            half3 n1_Y = UnpackGroundNormal(SAMPLE_TEXTURE2D(_TerrainNormal1, sampler_BumpMap, uv1_Y), _GroundBumpScale);
                            half3 n2_Y = UnpackGroundNormal(SAMPLE_TEXTURE2D(_TerrainNormal2, sampler_BumpMap, uv2_Y), _GroundBumpScale);
                            half3 n3_Y = UnpackGroundNormal(SAMPLE_TEXTURE2D(_TerrainNormal3, sampler_BumpMap, uv3_Y), _GroundBumpScale);
                            half3 nY = n0_Y * splatControl.r + n1_Y * splatControl.g + n2_Y * splatControl.b + n3_Y * splatControl.a;

                            half3 n0_Z = UnpackGroundNormal(SAMPLE_TEXTURE2D(_TerrainNormal0, sampler_BumpMap, uv0_Z), _GroundBumpScale);
                            half3 n1_Z = UnpackGroundNormal(SAMPLE_TEXTURE2D(_TerrainNormal1, sampler_BumpMap, uv1_Z), _GroundBumpScale);
                            half3 n2_Z = UnpackGroundNormal(SAMPLE_TEXTURE2D(_TerrainNormal2, sampler_BumpMap, uv2_Z), _GroundBumpScale);
                            half3 n3_Z = UnpackGroundNormal(SAMPLE_TEXTURE2D(_TerrainNormal3, sampler_BumpMap, uv3_Z), _GroundBumpScale);
                            half3 nZ = n0_Z * splatControl.r + n1_Z * splatControl.g + n2_Z * splatControl.b + n3_Z * splatControl.a;

                            groundNormalTS = nX * blendWeights.x + nY * blendWeights.y + nZ * blendWeights.z;
                        #else
                            float4 ts0 = _TerrainTileSizeHDRP0.x > 0.0001 ? _TerrainTileSizeHDRP0 : float4(0.1, 0.1, 0, 0);
                            float4 ts1 = _TerrainTileSizeHDRP1.x > 0.0001 ? _TerrainTileSizeHDRP1 : ts0;
                            float4 ts2 = _TerrainTileSizeHDRP2.x > 0.0001 ? _TerrainTileSizeHDRP2 : ts0;
                            float4 ts3 = _TerrainTileSizeHDRP3.x > 0.0001 ? _TerrainTileSizeHDRP3 : ts0;

                            float2 uv0 = tGroundXZ * ts0.xy + ts0.zw;
                            float2 uv1 = tGroundXZ * ts1.xy + ts1.zw;
                            float2 uv2 = tGroundXZ * ts2.xy + ts2.zw;
                            float2 uv3 = tGroundXZ * ts3.xy + ts3.zw;

                            half4 c0 = SAMPLE_TEXTURE2D(_TerrainSplat0, sampler_BaseMap, uv0);
                            half4 c1 = SAMPLE_TEXTURE2D(_TerrainSplat1, sampler_BaseMap, uv1);
                            half4 c2 = SAMPLE_TEXTURE2D(_TerrainSplat2, sampler_BaseMap, uv2);
                            half4 c3 = SAMPLE_TEXTURE2D(_TerrainSplat3, sampler_BaseMap, uv3);

                            half4 groundTint = (_GroundColor.r + _GroundColor.g + _GroundColor.b < 0.01) ? half4(1,1,1,1) : _GroundColor;
                            groundAlbedo = (c0 * splatControl.r + c1 * splatControl.g + c2 * splatControl.b + c3 * splatControl.a) * groundTint;

                            half3 n0 = UnpackGroundNormal(SAMPLE_TEXTURE2D(_TerrainNormal0, sampler_BumpMap, uv0), _GroundBumpScale);
                            half3 n1 = UnpackGroundNormal(SAMPLE_TEXTURE2D(_TerrainNormal1, sampler_BumpMap, uv1), _GroundBumpScale);
                            half3 n2 = UnpackGroundNormal(SAMPLE_TEXTURE2D(_TerrainNormal2, sampler_BumpMap, uv2), _GroundBumpScale);
                            half3 n3 = UnpackGroundNormal(SAMPLE_TEXTURE2D(_TerrainNormal3, sampler_BumpMap, uv3), _GroundBumpScale);

                            groundNormalTS = n0 * splatControl.r + n1 * splatControl.g + n2 * splatControl.b + n3 * splatControl.a;
                        #endif
                    }
                    else
                    {
                        #if defined(_TRIPLANAR_GROUND)
                            float3 blendWeights = pow(abs(input.normalWS), 4.0);
                            blendWeights = lerp(float3(0.0, 1.0, 0.0), blendWeights, blendFactor);
                            blendWeights /= max(0.00001, blendWeights.x + blendWeights.y + blendWeights.z);

                            float2 uvX = positionAWS.zy * _GroundTiling;
                            float2 uvY = groundXZ * _GroundTiling;
                            if (_HasGroundObjectHDRP >= 0.5) uvY = GroundObjectUV(float3(groundXZ.x, positionAWS.y, groundXZ.y));
                            float2 uvZ = positionAWS.xy * _GroundTiling;

                            half4 gX = SAMPLE_TEXTURE2D(_GroundAlbedoMap, sampler_BaseMap, uvX);
                            half4 gY = SAMPLE_TEXTURE2D(_GroundAlbedoMap, sampler_BaseMap, uvY);
                            half4 gZ = SAMPLE_TEXTURE2D(_GroundAlbedoMap, sampler_BaseMap, uvZ);

                            half4 groundTint = (_GroundColor.r + _GroundColor.g + _GroundColor.b < 0.01) ? half4(1,1,1,1) : _GroundColor;
                            groundAlbedo = (gX * blendWeights.x + gY * blendWeights.y + gZ * blendWeights.z) * groundTint;

                            half3 nX = UnpackGroundNormal(SAMPLE_TEXTURE2D(_GroundBumpMap, sampler_BumpMap, uvX), _GroundBumpScale);
                            half3 nY = UnpackGroundNormal(SAMPLE_TEXTURE2D(_GroundBumpMap, sampler_BumpMap, uvY), _GroundBumpScale);
                            half3 nZ = UnpackGroundNormal(SAMPLE_TEXTURE2D(_GroundBumpMap, sampler_BumpMap, uvZ), _GroundBumpScale);
                            groundNormalTS = nX * blendWeights.x + nY * blendWeights.y + nZ * blendWeights.z;
                        #else
                            float2 groundUV = groundXZ * _GroundTiling;
                            if (_HasGroundObjectHDRP >= 0.5) groundUV = GroundObjectUV(float3(groundXZ.x, positionAWS.y, groundXZ.y));
                            half4 groundTint = (_GroundColor.r + _GroundColor.g + _GroundColor.b < 0.01) ? half4(1,1,1,1) : _GroundColor;
                            groundAlbedo = SAMPLE_TEXTURE2D(_GroundAlbedoMap, sampler_BaseMap, groundUV) * groundTint;
                            groundNormalTS = UnpackGroundNormal(SAMPLE_TEXTURE2D(_GroundBumpMap, sampler_BumpMap, groundUV), _GroundBumpScale);
                        #endif
                    }
                }

                float3 groundNormalWS = normalize(float3(groundNormalTS.x, max(0.1, groundNormalTS.z), groundNormalTS.y));
                if (_HasGroundTexture >= 0.5 && _HasTerrainData < 0.5 && _HasGroundObjectHDRP >= 0.5)
                {
                    groundNormalWS = normalize(_GroundTangentWSHDRP.xyz * groundNormalTS.x
                                             + _GroundBitangentWSHDRP.xyz * groundNormalTS.y
                                             + _GroundNormalWSHDRP.xyz * max(0.1, groundNormalTS.z));
                }

                half4 finalAlbedo = lerp(groundAlbedo, objectAlbedo, blendFactor);
                half finalSmoothness = lerp(_GroundSmoothness, _Smoothness, blendFactor);
                half finalMetallic = lerp(0.0, _Metallic, blendFactor);

                float3 targetGroundNormal = lerp(float3(0, 1, 0), groundNormalWS, _NormalBlendStrength);
                float3 finalNormalWS = normalize(lerp(targetGroundNormal, objectNormalWS, blendFactor));

                float3 V = GetWorldSpaceNormalizeViewDir(positionRWS);

                PositionInputs posInput = GetPositionInput(input.positionCS.xy, _ScreenSize.zw, uint2(input.positionCS.xy) / GetTileSize());
                posInput.positionWS = positionRWS;
                posInput.deviceDepth = input.positionCS.z;
                posInput.linearDepth = LinearEyeDepth(positionRWS, GetWorldToViewMatrix());

                SurfaceData surfaceData;
                ZERO_INITIALIZE(SurfaceData, surfaceData);
                surfaceData.materialFeatures = MATERIALFEATUREFLAGS_LIT_STANDARD;
                surfaceData.baseColor = finalAlbedo.rgb;
                surfaceData.specularOcclusion = 1.0;
                surfaceData.normalWS = finalNormalWS;
                surfaceData.geomNormalWS = input.normalWS;
                surfaceData.tangentWS = normalize(input.tangentWS.xyz);
                surfaceData.perceptualSmoothness = finalSmoothness;
                surfaceData.ambientOcclusion = 1.0;
                surfaceData.metallic = finalMetallic;

                BuiltinData builtinData;
                InitBuiltinData(posInput, 1.0, surfaceData.normalWS, -surfaceData.geomNormalWS, input.uv1, input.uv2, builtinData);
                PostInitBuiltinData(V, posInput, surfaceData, builtinData);

                BSDFData bsdfData = ConvertSurfaceDataToBSDFData(uint2(input.positionCS.xy), surfaceData);
                PreLightData preLightData = GetPreLightData(V, posInput, bsdfData);

                uint featureFlags = LIGHT_FEATURE_MASK_FLAGS_OPAQUE;
                LightLoopOutput lightLoopOutput;
                LightLoop(V, posInput, preLightData, bsdfData, builtinData, featureFlags, lightLoopOutput);

                float3 diffuseLighting = lightLoopOutput.diffuseLighting;
                float3 specularLighting = lightLoopOutput.specularLighting;
                diffuseLighting *= GetCurrentExposureMultiplier();
                specularLighting *= GetCurrentExposureMultiplier();

                float4 outColor = float4(diffuseLighting + specularLighting, 1.0);
                outColor = EvaluateAtmosphericScattering(posInput, V, outColor);
                return outColor;
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
            #pragma vertex VertShadow
            #pragma fragment FragShadow

            #define PREFER_HALF 0
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShaderVariables.hlsl"
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/ShaderPass/FragInputs.hlsl"
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/ShaderPass/ShaderPass.cs.hlsl"
            #define SHADERPASS SHADERPASS_SHADOWS

            struct Attributes
            {
                float3 positionOS   : POSITION;
            };

            struct Varyings
            {
                float4 positionCS   : SV_POSITION;
            };

            TEXTURE2D(_BaseMap);           SAMPLER(sampler_BaseMap);
            TEXTURE2D(_BumpMap);           SAMPLER(sampler_BumpMap);
            TEXTURE2D(_GroundAlbedoMap);
            TEXTURE2D(_GroundBumpMap);

            TEXTURE2D(_TerrainControl);
            TEXTURE2D(_TerrainSplat0);
            TEXTURE2D(_TerrainSplat1);
            TEXTURE2D(_TerrainSplat2);
            TEXTURE2D(_TerrainSplat3);
            TEXTURE2D(_TerrainNormal0);
            TEXTURE2D(_TerrainNormal1);
            TEXTURE2D(_TerrainNormal2);
            TEXTURE2D(_TerrainNormal3);

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

                float _HasTerrainData;
            CBUFFER_END

            float4 _TerrainPositionHDRP;
            float4 _TerrainSizeHDRP;
            float4 _TerrainTileSizeHDRP0;
            float4 _TerrainTileSizeHDRP1;
            float4 _TerrainTileSizeHDRP2;
            float4 _TerrainTileSizeHDRP3;

            float4x4 _GroundWorldToLocalHDRP;
            float4 _GroundUGradHDRP;
            float4 _GroundVGradHDRP;
            float4 _GroundSTHDRP;
            float4 _GroundTangentWSHDRP;
            float4 _GroundBitangentWSHDRP;
            float4 _GroundNormalWSHDRP;
            float _HasGroundObjectHDRP;


            Varyings VertShadow(Attributes input)
            {
                Varyings output;
                float3 positionRWS = TransformObjectToWorld(input.positionOS);
                output.positionCS = TransformWorldToHClip(positionRWS);
                return output;
            }

            void FragShadow(Varyings input)
            {
            }
            ENDHLSL
        }
    }
    CustomEditor "GroundBlendShaderGUIHDRP"
}
