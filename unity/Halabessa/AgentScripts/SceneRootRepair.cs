using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

// Explicitly approved repair of a dangling root only. Never rebuilds a scene.
public static class SceneRootRepair {
    public static object Repair() {
        const string path = "Assets/GameScene.unity";
        var original = File.ReadAllText(path);
        if (!original.Contains("{fileID: 293843866}") || original.Contains("&293843866"))
            throw new Exception("Expected dangling reference is absent or resolves to an object; no save performed.");
        var backup = Path.GetFullPath(Path.Combine(Application.dataPath,
            "../../../build/unity-scene-before-root-repair.unity"));
        if (!File.Exists(backup)) File.Copy(path, backup);
        var scene = EditorSceneManager.OpenScene(path, OpenSceneMode.Single);
        var objects = scene.GetRootGameObjects().OrderBy(o => o.name).ToArray();
        var before = objects.SelectMany(o => o.GetComponentsInChildren<Component>(true))
            .Where(c => c != null).Select(c => EditorJsonUtility.ToJson(c)).ToArray();
        if (!EditorSceneManager.SaveScene(scene, path)) throw new Exception("Editor scene save failed.");
        var after = objects.SelectMany(o => o.GetComponentsInChildren<Component>(true))
            .Where(c => c != null).Select(c => EditorJsonUtility.ToJson(c)).ToArray();
        if (!before.SequenceEqual(after)) throw new Exception("Component values changed; review backup before proceeding.");
        if (File.ReadAllText(path).Contains("{fileID: 293843866}"))
            throw new Exception("Editor did not remove the dangling root.");
        return new { roots = objects.Select(o => o.name).ToArray(), componentsUnchanged = true, backup = backup };
    }
}
