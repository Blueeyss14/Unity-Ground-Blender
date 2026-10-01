using UnityEngine;
using UnityEngine.Rendering;

[ExecuteAlways]
[AddComponentMenu("Rendering/Ground Blender URP")]
public class GroundBlender : MonoBehaviour
{
    [SerializeField] private Terrain targetTerrain;
    [SerializeField] private bool autoUpdateInEditor = true;

    private void OnEnable()
    {
        RenderPipelineManager.beginCameraRendering += OnBeginCameraRendering;
        SyncTerrain();
    }

    private void OnDisable()
    {
        RenderPipelineManager.beginCameraRendering -= OnBeginCameraRendering;
    }

    private void OnBeginCameraRendering(ScriptableRenderContext context, Camera cam)
    {
        SyncTransform();
    }

    private void OnValidate()
    {
        if (autoUpdateInEditor)
        {
            SyncTerrain();
        }
    }

    private void Update()
    {
        SyncTransform();

        if (!Application.isPlaying && autoUpdateInEditor)
        {
            SyncTerrain();
        }
    }

    private void SyncTransform()
    {
        if (targetTerrain == null)
        {
            targetTerrain = Terrain.activeTerrain;
        }
        if (targetTerrain == null || targetTerrain.terrainData == null) return;

        Vector3 pos = targetTerrain.transform.position;
        Vector3 size = targetTerrain.terrainData.size;
        Shader.SetGlobalVector("_TerrainPosition", new Vector4(pos.x, pos.y, pos.z, 0));
        Shader.SetGlobalVector("_TerrainSize", new Vector4(size.x, size.y, size.z, 0));
        GroundBlenderAutoSync.PushTileData(targetTerrain.terrainData.terrainLayers);
    }

    [ContextMenu("Sync Terrain Splatmaps")]
    public void SyncTerrain()
    {
        if (targetTerrain == null)
        {
            targetTerrain = Terrain.activeTerrain;
        }

        if (targetTerrain == null || targetTerrain.terrainData == null) return;

        TerrainData tData = targetTerrain.terrainData;

        Texture2D[] alphaTexs = tData.alphamapTextures;
        if (alphaTexs != null && alphaTexs.Length > 0 && alphaTexs[0] != null)
        {
            Shader.SetGlobalTexture("_TerrainControl", alphaTexs[0]);
        }

        TerrainLayer[] layers = tData.terrainLayers;
        if (layers != null)
        {
            for (int i = 0; i < 4; i++)
            {
                Texture2D diffuse = null;
                Texture2D normal = null;

                if (i < layers.Length && layers[i] != null)
                {
                    diffuse = layers[i].diffuseTexture;
                    normal = layers[i].normalMapTexture;
                }

                string texProp = "_TerrainSplat" + i;
                string normProp = "_TerrainNormal" + i;

                if (diffuse != null)
                {
                    Shader.SetGlobalTexture(texProp, diffuse);
                }
                if (normal != null)
                {
                    Shader.SetGlobalTexture(normProp, normal);
                }
            }
        }

        GroundBlenderAutoSync.PushTileData(layers);

        SyncTransform();
        Shader.SetGlobalFloat("_HasTerrainData", 1.0f);
    }

    [ContextMenu("Print Terrain Debug")]
    private void PrintDebug()
    {
        Terrain t = targetTerrain != null ? targetTerrain : Terrain.activeTerrain;
        if (t == null) { Debug.LogError("[GroundBlender] Terrain NULL"); return; }
        SyncTransform();
        Debug.Log("[GroundBlender] Terrain: " + t.name + " | transform pos: " + t.transform.position +
                  " | global _TerrainPosition: " + Shader.GetGlobalVector("_TerrainPosition") +
                  " | global _TerrainSize: " + Shader.GetGlobalVector("_TerrainSize"));
    }
}

public static class GroundBlenderAutoSync
{
#if UNITY_EDITOR
    [UnityEditor.InitializeOnLoadMethod]
#endif
    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterAssembliesLoaded)]
    private static void Init()
    {
        RenderPipelineManager.beginCameraRendering -= OnBeginCameraRendering;
        RenderPipelineManager.beginCameraRendering += OnBeginCameraRendering;
    }

    private static void OnBeginCameraRendering(ScriptableRenderContext context, Camera cam)
    {
        Terrain t = Terrain.activeTerrain;
        if (t == null || t.terrainData == null) return;

        Vector3 pos = t.transform.position;
        Vector3 size = t.terrainData.size;
        Shader.SetGlobalVector("_TerrainPosition", new Vector4(pos.x, pos.y, pos.z, 0));
        Shader.SetGlobalVector("_TerrainSize", new Vector4(size.x, size.y, size.z, 0));
        PushTileData(t.terrainData.terrainLayers);
    }

    public static void PushTileData(TerrainLayer[] layers)
    {
        for (int i = 0; i < 4; i++)
        {
            Vector4 v = new Vector4(0.1f, 0.1f, 0f, 0f);
            if (layers != null && i < layers.Length && layers[i] != null)
            {
                Vector2 ts = layers[i].tileSize;
                Vector2 to = layers[i].tileOffset;
                float sx = ts.x > 0.001f ? ts.x : 10f;
                float sy = ts.y > 0.001f ? ts.y : 10f;
                v = new Vector4(1f / sx, 1f / sy, to.x / sx, to.y / sy);
            }
            Shader.SetGlobalVector("_TerrainTileSize" + i, v);
        }
    }
}