using System;
using System.IO;
using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEngine;

// An explicitly invoked, isolated build. Never overwrites embedded Flutter exports.
public static class VisualBuildCheck {
    public static object Web() {
        if (Application.isPlaying) throw new Exception("Stop isolated Play Mode before building.");
        if (EditorUserBuildSettings.activeBuildTarget != BuildTarget.WebGL) {
            throw new Exception("Select the WebGL build target and finish its domain reload before this check.");
        }
        var checkout = Path.GetFullPath(Path.Combine(Application.dataPath, "../../.."));
        var output = Path.Combine(checkout, "build", "unity-spices-qa", "web");
        Directory.CreateDirectory(output);
        var options = new BuildPlayerOptions {
            scenes = new[] { "Assets/GameScene.unity" },
            locationPathName = output,
            target = BuildTarget.WebGL,
            options = BuildOptions.None
        };
        var report = BuildPipeline.BuildPlayer(options);
        if (report.summary.result != BuildResult.Succeeded) {
            Debug.LogError("[HalabessaQa] Isolated WebGL build failed: " + report.summary.totalErrors + " errors.");
        }
        return Describe(report);
    }

    // Read the persisted report after a long build outlives the CLI request.
    // This does not start another build or change any project settings.
    public static object Latest() {
        var report = BuildReport.GetLatestReport();
        if (report == null) throw new Exception("No completed Unity build report is available.");
        return Describe(report);
    }

    private static object Describe(BuildReport report) {
        return new {
            target = report.summary.platform.ToString(), result = report.summary.result.ToString(),
            errors = report.summary.totalErrors, warnings = report.summary.totalWarnings,
            bytes = report.summary.totalSize, seconds = report.summary.totalTime.TotalSeconds,
            output = report.summary.outputPath, finishedUtc = report.summary.buildEndedAt.ToUniversalTime().ToString("o")
        };
    }
}
