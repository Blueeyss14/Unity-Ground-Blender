using UnityEngine;
using UnityEditor;

[CustomEditor(typeof(GroundBlenderHDRP))]
public class GroundBlenderEditorHDRP : Editor
{
    public override void OnInspectorGUI()
    {
        GroundBlenderHDRP script = (GroundBlenderHDRP)target;

        DrawDefaultInspector();

        EditorGUILayout.Space(10);

        if (GUILayout.Button("Sync Ground Textures Now", GUILayout.Height(30)))
        {
            script.SyncTerrain();
            EditorUtility.SetDirty(script);
        }
    }
}
