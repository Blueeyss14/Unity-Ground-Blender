using UnityEngine;
using UnityEditor;

[CustomEditor(typeof(GroundBlender))]
public class GroundBlenderEditor : Editor
{
    public override void OnInspectorGUI()
    {
        GroundBlender script = (GroundBlender)target;

        DrawDefaultInspector();

        EditorGUILayout.Space(10);

        if (GUILayout.Button("Sync Ground Textures Now", GUILayout.Height(30)))
        {
            script.SyncTerrain();
            EditorUtility.SetDirty(script);
        }
    }
}
