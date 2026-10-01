using System.Collections.Generic;
using UnityEngine;

[ExecuteAlways]
[DisallowMultipleComponent]
[AddComponentMenu("")]
public class GroundBlenderSource : MonoBehaviour
{
    public static readonly List<GroundBlenderSource> All = new List<GroundBlenderSource>();

    public static GroundBlenderSource Current
    {
        get
        {
            for (int i = All.Count - 1; i >= 0; i--)
            {
                if (All[i] != null) return All[i];
            }
            return null;
        }
    }

    private Mesh cachedMesh;
    private Vector3 gu, gv, nLocal;
    private float u0, v0;

    private void OnEnable()
    {
        if (!All.Contains(this)) All.Add(this);
    }

    private void OnDisable()
    {
        All.Remove(this);
    }

    public void Push()
    {
        EnsureMapping();
        Transform tr = transform;

        Shader.SetGlobalMatrix("_GroundWorldToLocal", tr.worldToLocalMatrix);
        Shader.SetGlobalVector("_GroundUGrad", new Vector4(gu.x, gu.y, gu.z, u0));
        Shader.SetGlobalVector("_GroundVGrad", new Vector4(gv.x, gv.y, gv.z, v0));

        Vector4 st = new Vector4(1, 1, 0, 0);
        Renderer r = GetComponent<Renderer>();
        if (r != null && r.sharedMaterial != null)
        {
            Material m = r.sharedMaterial;
            string p = m.HasProperty("_BaseMap") ? "_BaseMap" : (m.HasProperty("_MainTex") ? "_MainTex" : null);
            if (p != null)
            {
                Vector2 s = m.GetTextureScale(p);
                Vector2 o = m.GetTextureOffset(p);
                st = new Vector4(s.x, s.y, o.x, o.y);
            }
        }
        Shader.SetGlobalVector("_GroundST", st);

        Vector3 t = tr.TransformVector(gu / Mathf.Max(1e-8f, gu.sqrMagnitude)).normalized;
        Vector3 b = tr.TransformVector(gv / Mathf.Max(1e-8f, gv.sqrMagnitude)).normalized;
        Vector3 n = tr.TransformDirection(nLocal).normalized;
        if (n.y < 0f) n = -n;
        Shader.SetGlobalVector("_GroundTangentWS", t);
        Shader.SetGlobalVector("_GroundBitangentWS", b);
        Shader.SetGlobalVector("_GroundNormalWS", n);

        Shader.SetGlobalFloat("_HasGroundObject", 1f);
    }

    private void EnsureMapping()
    {
        MeshFilter mf = GetComponent<MeshFilter>();
        Mesh mesh = mf != null ? mf.sharedMesh : null;
        if (mesh != null && mesh == cachedMesh) return;
        cachedMesh = mesh;

        if (mesh != null && mesh.isReadable && TryFitFromMesh(mesh)) return;

        Bounds b = mesh != null ? mesh.bounds : new Bounds(Vector3.zero, new Vector3(10f, 0f, 10f));
        FallbackFromBounds(b);
    }

    private bool TryFitFromMesh(Mesh mesh)
    {
        Vector3[] vs = mesh.vertices;
        Vector2[] uvs = mesh.uv;
        int[] tris = mesh.triangles;
        if (uvs == null || uvs.Length != vs.Length) return false;

        for (int i = 0; i + 2 < tris.Length; i += 3)
        {
            Vector3 p0 = vs[tris[i]], p1 = vs[tris[i + 1]], p2 = vs[tris[i + 2]];
            Vector3 e1 = p1 - p0, e2 = p2 - p0;
            Vector3 nn = Vector3.Cross(e1, e2);
            if (nn.sqrMagnitude < 1e-10f) continue;
            nn.Normalize();

            Vector2 a = uvs[tris[i]], b = uvs[tris[i + 1]], c = uvs[tris[i + 2]];
            float du1 = b.x - a.x, du2 = c.x - a.x;
            float dv1 = b.y - a.y, dv2 = c.y - a.y;
            if (Mathf.Abs(du1) + Mathf.Abs(du2) + Mathf.Abs(dv1) + Mathf.Abs(dv2) < 1e-8f) continue;

            float d = Vector3.Dot(e1, Vector3.Cross(e2, nn));
            if (Mathf.Abs(d) < 1e-10f) continue;

            Vector3 c2n = Vector3.Cross(e2, nn);
            Vector3 nc1 = Vector3.Cross(nn, e1);
            gu = (du1 * c2n + du2 * nc1) / d;
            gv = (dv1 * c2n + dv2 * nc1) / d;
            u0 = a.x - Vector3.Dot(gu, p0);
            v0 = a.y - Vector3.Dot(gv, p0);
            nLocal = nn;
            return true;
        }
        return false;
    }

    private void FallbackFromBounds(Bounds b)
    {
        float sx = Mathf.Max(1e-4f, b.size.x);
        float sz = Mathf.Max(1e-4f, b.size.z);
        gu = new Vector3(1f / sx, 0f, 0f);
        gv = new Vector3(0f, 0f, 1f / sz);
        u0 = -b.min.x / sx;
        v0 = -b.min.z / sz;
        nLocal = Vector3.up;
    }
}