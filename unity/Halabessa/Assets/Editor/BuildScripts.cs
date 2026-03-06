using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEngine;
using System.IO;

public class BuildScripts {
    [MenuItem("Halabessa/Export/Android (UaaL)")]
    public static void ExportAndroid() {
        string exportPath = Path.Combine(Application.dataPath, "../../../androidBuild/unityExport");
        
        // Match Firebase configuration
        PlayerSettings.SetApplicationIdentifier(BuildTargetGroup.Android, "com.example.halabessa");

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
        
        // Set iOS requirements for Firebase
        PlayerSettings.SetApplicationIdentifier(BuildTargetGroup.iOS, "com.example.halabessa");
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

    [MenuItem("Halabessa/Export/WebGL (Brotli)")]
    public static void ExportWebGL() {
        string exportPath = Path.Combine(Application.dataPath, "../../../assets/unity");
        if (!Directory.Exists(exportPath)) Directory.CreateDirectory(exportPath);

        // Configure Brotli
        PlayerSettings.WebGL.compressionFormat = WebGLCompressionFormat.Brotli;
        PlayerSettings.WebGL.decompressionFallback = true;

        BuildPlayerOptions options = new BuildPlayerOptions();
        options.scenes = GetEnabledScenes();
        options.locationPathName = exportPath;
        options.target = BuildTarget.WebGL;

        BuildReport report = BuildPipeline.BuildPlayer(options);
        Debug.Log("WebGL Export Done: " + report.summary.result);
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
