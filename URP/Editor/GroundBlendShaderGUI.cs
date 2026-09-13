using UnityEngine;
using UnityEditor;

public class GroundBlendShaderGUI : ShaderGUI
{
    private Terrain selectedTerrain;
    private GameObject selectedGameObject;
    private int selectedLayerIndex = 0;

    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        Material targetMat = materialEditor.target as Material;
        if (targetMat == null) return;

        if (selectedTerrain == null && selectedGameObject == null && targetMat.HasProperty("_HasGroundTexture") && targetMat.GetFloat("_HasGroundTexture") > 0.5f)
        {
            selectedTerrain = Terrain.activeTerrain;
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
                if (targetMat.HasProperty("_HasGroundTexture")) targetMat.SetFloat("_HasGroundTexture", 0.0f);
                EditorUtility.SetDirty(targetMat);
            }
        }

        if (selectedTerrain != null && selectedTerrain.terrainData != null)
        {
            TerrainLayer[] layers = selectedTerrain.terrainData.terrainLayers;
            if (layers != null && layers.Length > 0)
            {
                string[] layerNames = new string[layers.Length];
                for (int i = 0; i < layers.Length; i++)
                {
                    layerNames[i] = layers[i] != null ? $"Layer {i}: {layers[i].name}" : $"Layer {i}";
                }

                EditorGUI.BeginChangeCheck();
                selectedLayerIndex = EditorGUILayout.Popup("Terrain Layer", selectedLayerIndex, layerNames);
                if (EditorGUI.EndChangeCheck())
                {
                    ExtractAndApplyGroundTextures(targetMat, selectedTerrain, selectedGameObject);
                }
            }
        }

        float hasGround = targetMat.HasProperty("_HasGroundTexture") ? targetMat.GetFloat("_HasGroundTexture") : 0.0f;
        Texture groundAlbedo = targetMat.HasProperty("_GroundAlbedoMap") ? targetMat.GetTexture("_GroundAlbedoMap") : null;
        float groundTiling = targetMat.HasProperty("_GroundTiling") ? targetMat.GetFloat("_GroundTiling") : 0.1f;

        EditorGUILayout.Space(5);
        if (hasGround >= 0.5f && groundAlbedo != null)
        {
            EditorGUILayout.LabelField($"Status: Active ({groundAlbedo.name} | Tiling: {groundTiling:F3})", EditorStyles.miniBoldLabel);
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

        Texture2D albedoTex = null;
        Texture2D normalTex = null;
        float tiling = 0.1f;
        float smoothness = 0.2f;

        if (terrainSource != null && terrainSource.terrainData != null)
        {
            TerrainData tData = terrainSource.terrainData;
            TerrainLayer[] layers = tData.terrainLayers;
            if (layers != null && layers.Length > 0)
            {
                int index = Mathf.Clamp(selectedLayerIndex, 0, layers.Length - 1);
                TerrainLayer layer = layers[index];
                if (layer != null)
                {
                    albedoTex = layer.diffuseTexture;
                    normalTex = layer.normalMapTexture;
                    if (layer.tileSize.x > 0.001f)
                    {
                        tiling = 1.0f / layer.tileSize.x;
                    }
                    smoothness = layer.smoothness;
                }
            }
        }
        else if (goSource != null)
        {
            Renderer r = goSource.GetComponent<Renderer>();
            if (r != null && r.sharedMaterial != null)
            {
                Material groundMat = r.sharedMaterial;
                if (groundMat.HasProperty("_BaseMap")) albedoTex = groundMat.GetTexture("_BaseMap") as Texture2D;
                else if (groundMat.HasProperty("_MainTex")) albedoTex = groundMat.GetTexture("_MainTex") as Texture2D;

                if (groundMat.HasProperty("_BumpMap")) normalTex = groundMat.GetTexture("_BumpMap") as Texture2D;

                Vector2 scale = groundMat.GetTextureScale("_BaseMap");
                if (scale.x > 0) tiling = scale.x * 0.1f;
            }
        }

        Undo.RecordObject(mat, "Update Ground Blend Textures");

        if (albedoTex != null)
        {
            mat.SetTexture("_GroundAlbedoMap", albedoTex);
            if (normalTex != null) mat.SetTexture("_GroundBumpMap", normalTex);
            mat.SetFloat("_GroundTiling", tiling);
            mat.SetFloat("_GroundSmoothness", smoothness);
            if (mat.HasProperty("_HasGroundTexture")) mat.SetFloat("_HasGroundTexture", 1.0f);
        }
        else
        {
            mat.SetTexture("_GroundAlbedoMap", null);
            mat.SetTexture("_GroundBumpMap", null);
            if (mat.HasProperty("_HasGroundTexture")) mat.SetFloat("_HasGroundTexture", 0.0f);
        }

        EditorUtility.SetDirty(mat);
    }
}
