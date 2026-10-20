using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

// Read-only asset qualification; never supplies replacement art or game rules.
public static class VisualAssetAudit {
    public static object Inspect() {
        var scene = EditorSceneManager.OpenScene("Assets/GameScene.unity", OpenSceneMode.Single);
        var components = scene.GetRootGameObjects().SelectMany(o => o.GetComponentsInChildren<Component>(true)).ToArray();
        var camera = components.OfType<Camera>().First(c => c.CompareTag("MainCamera"));
        var deck = components.OfType<DeckManager>().Single();
        var prefab = AssetDatabase.LoadAssetAtPath<GameObject>("Assets/Resources/CardPrefab.prefab");
        var mesh = prefab.GetComponent<MeshFilter>().sharedMesh;
        var material = prefab.GetComponent<MeshRenderer>().sharedMaterial;
        var normal = mesh.normals.First();
        var position = new Vector3(0, .1f, -1);
        var toCamera = (camera.transform.position - position).normalized;
        return new {
            configuredSkins = deck.availableSkins == null ? 0 : deck.availableSkins.Count,
            hasCardInstanceOnPrefab = prefab.GetComponent<CardInstance>() != null,
            shader = material == null ? "none" : material.shader.name,
            texture = material == null || material.mainTexture == null ? "none" : material.mainTexture.name,
            meshNormal = normal.ToString(),
            tableFrontFacesCamera = Vector3.Dot(Quaternion.Euler(-90, 0, 0) * normal, toCamera) > 0,
            handFrontFacesCamera = Vector3.Dot(Quaternion.Euler(-60, 0, 0) * normal, toCamera) > 0,
            savedSceneDirty = scene.isDirty
        };
    }
}
