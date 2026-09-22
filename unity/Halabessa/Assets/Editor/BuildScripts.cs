using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEngine;
using System.IO;

public class BuildScripts {
    [MenuItem("Halabessa/Export/Android (UaaL)")]
    public static void ExportAndroid() {
        string exportPath = Path.Combine(Application.dataPath, "../../../androidBuild/unityExport");
        
        // Keep the embedded Unity library aligned with the Flutter app id.
        PlayerSettings.SetApplicationIdentifier(NamedBuildTarget.Android, "com.halabessa.game");

        // Ensure the target is a Gradle project for Flutter
        EditorUserBuildSettings.exportAsGoogleAndroidProject = true;
        EditorUserBuildSettings.androidBuildSystem = AndroidBuildSystem.Gradle;

        // Clean the directory to avoid conflict errors
        if (Directory.Exists(exportPath)) {
            Directory.Delete(exportPath, true);
        }
        Directory.CreateDirectory(exportPath);

        BuildPlayerOptions options = new BuildPlayerOptions();
        options.scenes = GetEnabledScenes();
        options.locationPathName = exportPath;
        options.target = BuildTarget.Android;
        options.options = BuildOptions.AcceptExternalModificationsToPlayer; 

        BuildReport report = BuildPipeline.BuildPlayer(options);
        Debug.Log("Android Export Done: " + report.summary.result);
    }

    [MenuItem("Halabessa/Export/iOS (UaaL)")]
    public static void ExportIOS() {
        string exportPath = Path.Combine(Application.dataPath, "../../../iosBuild/UnityLibrary");
        
        // Keep the embedded Unity library aligned with the Flutter app id.
        PlayerSettings.SetApplicationIdentifier(NamedBuildTarget.iOS, "com.halabessa.game");
        PlayerSettings.iOS.targetOSVersionString = "15.0";

        // Clean the directory to avoid conflicts
        if (Directory.Exists(exportPath)) {
            Directory.Delete(exportPath, true);
        }
        Directory.CreateDirectory(exportPath);

        BuildPlayerOptions options = new BuildPlayerOptions();
        options.scenes = GetEnabledScenes();
        options.locationPathName = exportPath;
        options.target = BuildTarget.iOS;
        
        BuildReport report = BuildPipeline.BuildPlayer(options);
        Debug.Log("iOS Export Done: " + report.summary.result);
    }

    // Single source of truth for the WebGL build. This used to be split
    // across two menu items (this one and Halabessa/Fix WebGL Transparency)
    // that disagreed about decompressionFallback -- whichever you clicked
    // last silently decided the output format, and firebase.json's hosting
    // headers have to match whichever one won. It also used to export to
    // assets/unity/, a path web/index.html never loads from (it loads
    // Build/web.*) that's gitignored anyway and never reaches CI.
    [MenuItem("Halabessa/Export/WebGL")]
    public static void ExportWebGL() {
        // Build into Temp/ (already gitignored) rather than straight into
        // web/. Unity's WebGL build regenerates index.html from its own
        // template on every run, which would clobber the hand-written
        // web/index.html and web/canvas.css that implement the
        // Flutter<->Unity bridge (HAL-03/UNI-02). Only the Build/ output --
        // renamed with the "web." prefix web/index.html expects -- and
        // StreamingAssets/ get copied into web/ afterward.
        string scratchPath = Path.Combine(Application.dataPath, "../Temp/WebGLExport");
        if (Directory.Exists(scratchPath)) Directory.Delete(scratchPath, true);
        Directory.CreateDirectory(scratchPath);

        // Transparency: linear color space + preserved framebuffer alpha,
        // required for the Unity canvas to composite over Flutter's UI.
        PlayerSettings.colorSpace = ColorSpace.Linear;
        PlayerSettings.preserveFramebufferAlpha = true;

        // Compression: Brotli with the JS-side decompression fallback left
        // ON. firebase.json intentionally sends **/Build/*.unityweb with NO
        // Content-Encoding header (see HAL-01) because that's what a
        // fallback=true build produces -- a JS-decompressed container, not
        // raw brotli. Flipping this to false changes the output extension
        // to .br and needs firebase.json's headers updated to match; don't
        // change one without the other.
        PlayerSettings.WebGL.compressionFormat = WebGLCompressionFormat.Brotli;
        PlayerSettings.WebGL.decompressionFallback = true;

        BuildPlayerOptions options = new BuildPlayerOptions();
        options.scenes = GetEnabledScenes();
        options.locationPathName = scratchPath;
        options.target = BuildTarget.WebGL;

        BuildReport report = BuildPipeline.BuildPlayer(options);
        if (report.summary.result != BuildResult.Succeeded) {
            Debug.LogError("WebGL Export failed: " + report.summary.result);
            return;
        }

        string webRoot = Path.Combine(Application.dataPath, "../../../web");
        string flutterBuildDir = Path.Combine(webRoot, "Build");
        Directory.CreateDirectory(flutterBuildDir);

        string productName = PlayerSettings.productName;
        foreach (string file in Directory.GetFiles(Path.Combine(scratchPath, "Build"))) {
            string fileName = Path.GetFileName(file);
            // Unity names build output after the product name
            // ("Halabessa.wasm.unityweb"); web/index.html loads it with a
            // "web." prefix instead ("web.wasm.unityweb").
            string suffix = fileName.StartsWith(productName) ? fileName.Substring(productName.Length) : fileName;
            File.Copy(file, Path.Combine(flutterBuildDir, "web" + suffix), true);
        }

        string scratchStreamingAssets = Path.Combine(scratchPath, "StreamingAssets");
        if (Directory.Exists(scratchStreamingAssets)) {
            CopyDirectoryRecursive(scratchStreamingAssets, Path.Combine(webRoot, "StreamingAssets"));
        }

        Directory.Delete(scratchPath, true);
        Debug.Log("WebGL Export Done: copied Build output into web/Build/.");
    }

    private static void CopyDirectoryRecursive(string sourceDir, string destDir) {
        Directory.CreateDirectory(destDir);
        foreach (string file in Directory.GetFiles(sourceDir)) {
            File.Copy(file, Path.Combine(destDir, Path.GetFileName(file)), true);
        }
        foreach (string subDir in Directory.GetDirectories(sourceDir)) {
            CopyDirectoryRecursive(subDir, Path.Combine(destDir, Path.GetFileName(subDir)));
        }
    }

    private static string[] GetEnabledScenes() {
        var scenes = EditorBuildSettings.scenes;
        string[] scenePaths = new string[scenes.Length];
        for (int i = 0; i < scenes.Length; i++) {
            scenePaths[i] = scenes[i].path;
        }
        return scenePaths;
    }
}
