using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEngine;

// Import only mechanically baked existing Flutter art. No scene/prefab rebuild.
public static class ImportCardArtwork {
    public static object Run() {
        if (Application.isPlaying) throw new Exception("Stop Play Mode before asset import.");
        var checkout = Path.GetFullPath(Path.Combine(Application.dataPath, "../../.."));
        var source = Path.Combine(checkout, "build", "unity-card-art");
        var files = Directory.GetFiles(source, "*.png", SearchOption.AllDirectories);
        if (files.Length != 159) throw new Exception("Expected 156 faces and three backs.");
        const string folder = "Assets/Resources/HalabessaCards";
        Directory.CreateDirectory(folder);
        foreach (var file in files) {
            var relative = file.Substring(source.Length + 1).Replace('\\', '/');
            var target = folder + "/" + relative;
            Directory.CreateDirectory(Path.GetDirectoryName(target));
            File.Copy(file, target, true);
        }
        AssetDatabase.Refresh();
        foreach (var file in files) {
            var path = folder + "/" + file.Substring(source.Length + 1).Replace('\\', '/');
            var importer = AssetImporter.GetAtPath(path) as TextureImporter;
            if (importer == null) throw new Exception("Texture importer missing: " + path);
            importer.textureType = TextureImporterType.Default;
            importer.mipmapEnabled = false;
            importer.alphaIsTransparency = true;
            importer.wrapMode = TextureWrapMode.Clamp;
            importer.filterMode = FilterMode.Bilinear;
            importer.maxTextureSize = 512;
            importer.npotScale = TextureImporterNPOTScale.None;
            importer.textureCompression = TextureImporterCompression.Uncompressed;
            importer.SaveAndReimport();
        }
        var mesh = AssetDatabase.LoadAssetAtPath<Mesh>(folder + "/CardMesh.asset");
        if (mesh == null) {
            var prefab = AssetDatabase.LoadAssetAtPath<GameObject>("Assets/Resources/CardPrefab.prefab");
            mesh = UnityEngine.Object.Instantiate(prefab.GetComponent<MeshFilter>().sharedMesh);
            mesh.name = "HalabessaCardQuad";
            mesh.vertices = mesh.vertices.Select(v => new Vector3(v.x * .7f, v.y, v.z)).ToArray();
            mesh.colors = Enumerable.Repeat(Color.white, mesh.vertexCount).ToArray();
            mesh.RecalculateBounds();
            AssetDatabase.CreateAsset(mesh, folder + "/CardMesh.asset");
        }
        var material = AssetDatabase.LoadAssetAtPath<Material>(folder + "/CardFaceMaterial.mat");
        if (material == null) {
            var shader = Shader.Find("Sprites/Default");
            if (shader == null) throw new Exception("Built-in transparent card shader is unavailable.");
            material = new Material(shader) { name = "HalabessaCardArtwork", color = Color.white };
            AssetDatabase.CreateAsset(material, folder + "/CardFaceMaterial.mat");
        }
        AssetDatabase.SaveAssets();
        return new { textures = files.Length, mesh = mesh.name, shader = material.shader.name,
            prefabUnchanged = true, sceneUnchanged = true };
    }
}
