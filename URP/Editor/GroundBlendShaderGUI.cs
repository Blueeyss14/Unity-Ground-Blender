using UnityEngine;
using UnityEditor;

public class GroundBlendShaderGUI : ShaderGUI
{
    private Terrain selectedTerrain;
    private GameObject selectedGameObject;

    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        Material targetMat = materialEditor.target as Material;
        if (targetMat == null) return;

        if (selectedTerrain == null && selectedGameObject == null && targetMat.HasProperty("_HasGroundTexture") && targetMat.GetFloat("_HasGroundTexture") > 0.5f)
        {
            selectedTerrain = Terrain.activeTerrain;
            if (selectedTerrain != null)
            {
                ExtractAndApplyGroundTextures(targetMat, selectedTerrain, null);
            }
        }

        EditorGUILayout.LabelField("Object Settings", EditorStyles.boldLabel);
        MaterialProperty baseMap = FindProperty("_BaseMap", properties);
        MaterialProperty baseColor = FindProperty("_BaseColor", properties);
        MaterialProperty bumpMap = FindProperty("_BumpMap", properties);
        MaterialProperty bumpScale = FindProperty("_BumpScale", properties);
        MaterialProperty smoothness = FindProperty("_Smoothness", properties);
        MaterialProperty metallic = FindProperty("_Metallic", properties);

        materialEditor.ShaderProperty(baseMap, "Object Texture (Albedo)");
        materialEditor.ShaderProperty(baseColor, "Object Color Tint");
        materialEditor.ShaderProperty(bumpMap, "Object Normal Map");
        materialEditor.ShaderProperty(bumpScale, "Object Normal Scale");
        materialEditor.ShaderProperty(smoothness, "Object Smoothness");
        materialEditor.ShaderProperty(metallic, "Object Metallic");

        EditorGUILayout.Space(15);

        EditorGUILayout.BeginVertical(EditorStyles.helpBox);
        EditorGUILayout.LabelField("Ground Terrain Drag & Drop", EditorStyles.boldLabel);
        EditorGUILayout.HelpBox("Drag & drop your Terrain (or Ground GameObject) directly into the box below to enable ground blending!", MessageType.Info);

        EditorGUI.BeginChangeCheck();
        UnityEngine.Object currentSource = selectedTerrain != null ? (UnityEngine.Object)selectedTerrain : (UnityEngine.Object)selectedGameObject;
        UnityEngine.Object newSource = EditorGUILayout.ObjectField("Target Terrain / Ground", currentSource, typeof(UnityEngine.Object), true);

        if (EditorGUI.EndChangeCheck())
        {
            if (newSource is Terrain t)
            {
                selectedTerrain = t;
                selectedGameObject = null;
                ExtractAndApplyGroundTextures(targetMat, selectedTerrain, null);
            }
            else if (newSource is GameObject go)
            {
                selectedTerrain = go.GetComponent<Terrain>();
                selectedGameObject = go;
                ExtractAndApplyGroundTextures(targetMat, selectedTerrain, go);
            }
            else
            {
                selectedTerrain = null;
                selectedGameObject = null;
                Undo.RecordObject(targetMat, "Clear Ground Textures");
                targetMat.SetTexture("_GroundAlbedoMap", null);
                targetMat.SetTexture("_GroundBumpMap", null);
                targetMat.SetTexture("_TerrainControl", null);
                for (int i = 0; i < 4; i++)
                {
                    targetMat.SetTexture("_TerrainSplat" + i, null);
                    targetMat.SetTexture("_TerrainNormal" + i, null);
                }
                if (targetMat.HasProperty("_HasGroundTexture")) targetMat.SetFloat("_HasGroundTexture", 0.0f);
                if (targetMat.HasProperty("_HasTerrainData")) targetMat.SetFloat("_HasTerrainData", 0.0f);
                EditorUtility.SetDirty(targetMat);
            }
        }

        float hasGround = targetMat.HasProperty("_HasGroundTexture") ? targetMat.GetFloat("_HasGroundTexture") : 0.0f;
        float hasTerrain = targetMat.HasProperty("_HasTerrainData") ? targetMat.GetFloat("_HasTerrainData") : 0.0f;

        EditorGUILayout.Space(5);
        if (hasGround >= 0.5f)
        {
            if (hasTerrain >= 0.5f && selectedTerrain != null)
            {
                EditorGUILayout.LabelField($"Status: Active ({selectedTerrain.name} | All Layers Blended)", EditorStyles.miniBoldLabel);
            }
            else
            {
                Texture groundAlbedo = targetMat.HasProperty("_GroundAlbedoMap") ? targetMat.GetTexture("_GroundAlbedoMap") : null;
                float groundTiling = targetMat.HasProperty("_GroundTiling") ? targetMat.GetFloat("_GroundTiling") : 0.1f;
                string texName = groundAlbedo != null ? groundAlbedo.name : "Active";
                EditorGUILayout.LabelField($"Status: Active ({texName} | Tiling: {groundTiling:F3})", EditorStyles.miniBoldLabel);
            }
        }
        else
        {
            EditorGUILayout.LabelField("Status: Off (No Terrain Assigned)", EditorStyles.miniLabel);
        }

        EditorGUILayout.EndVertical();

        EditorGUILayout.Space(15);

        EditorGUILayout.LabelField("Blending Parameters", EditorStyles.boldLabel);
        MaterialProperty blendDist = FindProperty("_BlendDistance", properties);
        MaterialProperty blendFalloff = FindProperty("_BlendContrast", properties);
        MaterialProperty normalBlend = FindProperty("_NormalBlendStrength", properties);
        MaterialProperty useTriplanar = FindProperty("_UseTriplanarGround", properties);

        materialEditor.ShaderProperty(blendDist, "Blend Distance (Height)");
        materialEditor.ShaderProperty(blendFalloff, "Blend Falloff / Softness");
        materialEditor.ShaderProperty(normalBlend, "Normal Blend Strength");
        materialEditor.ShaderProperty(useTriplanar, "Use Triplanar Mapping for Ground");
    }

    private void ExtractAndApplyGroundTextures(Material mat, Terrain terrainSource, GameObject goSource)
    {
        if (mat == null) return;

        Undo.RecordObject(mat, "Update Ground Blend Textures");

        if (terrainSource != null && terrainSource.terrainData != null)
        {
            mat.SetColor("_GroundColor", Color.white);
            TerrainData tData = terrainSource.terrainData;
            Texture2D[] alphaTexs = tData.alphamapTextures;
            if (alphaTexs != null && alphaTexs.Length > 0 && alphaTexs[0] != null)
            {
                mat.SetTexture("_TerrainControl", alphaTexs[0]);
                Shader.SetGlobalTexture("_TerrainControl", alphaTexs[0]);
            }

            TerrainLayer[] layers = tData.terrainLayers;
            if (layers != null)
            {
                for (int i = 0; i < 4; i++)
                {
                    Texture2D diffuse = null;
                    Texture2D normal = null;
                    float tiling = 0.1f;

                    if (i < layers.Length && layers[i] != null)
                    {
                        diffuse = layers[i].diffuseTexture;
                        normal = layers[i].normalMapTexture;
                        if (layers[i].tileSize.x > 0.001f)
                        {
                            tiling = 1.0f / layers[i].tileSize.x;
                        }
                    }

                    mat.SetTexture("_TerrainSplat" + i, diffuse);
                    mat.SetTexture("_TerrainNormal" + i, normal);
                    mat.SetVector("_TerrainTileSize" + i, new Vector4(tiling, tiling, 0, 0));

                    if (diffuse != null) Shader.SetGlobalTexture("_TerrainSplat" + i, diffuse);
                    if (normal != null) Shader.SetGlobalTexture("_TerrainNormal" + i, normal);
                    Shader.SetGlobalVector("_TerrainTileSize" + i, new Vector4(tiling, tiling, 0, 0));
                }

                if (layers.Length > 0 && layers[0] != null)
                {
                    mat.SetTexture("_GroundAlbedoMap", layers[0].diffuseTexture);
                }
            }

            Vector3 pos = terrainSource.transform.position;
            Vector3 size = tData.size;
            Vector4 posVec = new Vector4(pos.x, pos.y, pos.z, 0);
            Vector4 sizeVec = new Vector4(size.x, size.y, size.z, 0);

            mat.SetVector("_TerrainPosition", posVec);
            mat.SetVector("_TerrainSize", sizeVec);
            Shader.SetGlobalVector("_TerrainPosition", posVec);
            Shader.SetGlobalVector("_TerrainSize", sizeVec);

            if (mat.HasProperty("_HasTerrainData")) mat.SetFloat("_HasTerrainData", 1.0f);
            if (mat.HasProperty("_HasGroundTexture")) mat.SetFloat("_HasGroundTexture", 1.0f);
            Shader.SetGlobalFloat("_HasTerrainData", 1.0f);
        }
        else if (goSource != null)
        {
            Renderer r = goSource.GetComponent<Renderer>();
            Texture2D albedoTex = null;
            Texture2D normalTex = null;
            float tiling = 0.1f;

            if (r != null && r.sharedMaterial != null)
            {
                Material groundMat = r.sharedMaterial;
                if (groundMat.HasProperty("_BaseMap")) albedoTex = groundMat.GetTexture("_BaseMap") as Texture2D;
                else if (groundMat.HasProperty("_MainTex")) albedoTex = groundMat.GetTexture("_MainTex") as Texture2D;

                if (groundMat.HasProperty("_BumpMap")) normalTex = groundMat.GetTexture("_BumpMap") as Texture2D;

                Vector2 scale = groundMat.GetTextureScale("_BaseMap");
                if (scale.x > 0) tiling = scale.x * 0.1f;
            }

            if (mat.HasProperty("_HasTerrainData")) mat.SetFloat("_HasTerrainData", 0.0f);
            Shader.SetGlobalFloat("_HasTerrainData", 0.0f);
            if (albedoTex != null)
            {
                mat.SetTexture("_GroundAlbedoMap", albedoTex);
                if (normalTex != null) mat.SetTexture("_GroundBumpMap", normalTex);
                mat.SetFloat("_GroundTiling", tiling);
                if (mat.HasProperty("_HasGroundTexture")) mat.SetFloat("_HasGroundTexture", 1.0f);
            }
            else
            {
                mat.SetTexture("_GroundAlbedoMap", null);
                mat.SetTexture("_GroundBumpMap", null);
                if (mat.HasProperty("_HasGroundTexture")) mat.SetFloat("_HasGroundTexture", 0.0f);
            }
        }
        else
        {
            if (mat.HasProperty("_HasTerrainData")) mat.SetFloat("_HasTerrainData", 0.0f);
            Shader.SetGlobalFloat("_HasTerrainData", 0.0f);
            mat.SetTexture("_GroundAlbedoMap", null);
            mat.SetTexture("_GroundBumpMap", null);
            mat.SetTexture("_TerrainControl", null);
            for (int i = 0; i < 4; i++)
            {
                mat.SetTexture("_TerrainSplat" + i, null);
                mat.SetTexture("_TerrainNormal" + i, null);
            }
            if (mat.HasProperty("_HasGroundTexture")) mat.SetFloat("_HasGroundTexture", 0.0f);
        }

        EditorUtility.SetDirty(mat);
    }
}
