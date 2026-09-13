using UnityEngine;

[ExecuteAlways]
[AddComponentMenu("Rendering/Ground Blender URP")]
public class GroundBlender : MonoBehaviour
{
    [SerializeField] private Terrain targetTerrain;
    [SerializeField] private bool autoUpdateInEditor = true;

    private void OnEnable()
    {
        SyncTerrain();
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
        if (!Application.isPlaying && autoUpdateInEditor)
        {
            SyncTerrain();
        }
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

                string texProp = "_TerrainSplat" + i;
                string normProp = "_TerrainNormal" + i;
                string tileProp = "_TerrainTileSize" + i;

                if (diffuse != null)
                {
                    Shader.SetGlobalTexture(texProp, diffuse);
                }
                if (normal != null)
                {
                    Shader.SetGlobalTexture(normProp, normal);
                }
                Shader.SetGlobalVector(tileProp, new Vector4(tiling, tiling, 0, 0));
            }
        }

        Vector3 pos = targetTerrain.transform.position;
        Vector3 size = tData.size;
        Shader.SetGlobalVector("_TerrainPosition", new Vector4(pos.x, pos.y, pos.z, 0));
        Shader.SetGlobalVector("_TerrainSize", new Vector4(size.x, size.y, size.z, 0));
        Shader.SetGlobalFloat("_HasTerrainData", 1.0f);
    }
}
