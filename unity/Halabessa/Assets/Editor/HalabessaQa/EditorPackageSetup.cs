using UnityEditor;
using UnityEditor.PackageManager;
using UnityEditor.PackageManager.Requests;
using UnityEngine;
using System;
using System.IO;
using UnityEditor.Build.Reporting;

namespace HalabessaQa {
    // Explicitly invoked tooling only. Never runs automatically or ships in a player.
    public static class EditorPackageSetup {
        private static AddRequest request;
        private static double deadline;

        [Serializable]
        private class BuildVerdict {
            public string target, result, output, finishedUtc;
            public int errors, warnings;
            public ulong bytes;
            public double seconds;
            public string[] diagnostics;
        }

        public static void BuildIsolatedWeb() {
            if (EditorUserBuildSettings.activeBuildTarget != BuildTarget.WebGL || Application.isPlaying) {
                Debug.LogError("[HalabessaQa] Isolated web build requires WebGL target and stopped Play Mode.");
                EditorApplication.Exit(2);
                return;
            }
            var checkout = Path.GetFullPath(Path.Combine(Application.dataPath, "../../.."));
            var output = Path.Combine(checkout, "build", "unity-spices-qa", "web");
            Directory.CreateDirectory(output);
            BuildPipeline.BuildPlayer(new BuildPlayerOptions {
                scenes = new[] { "Assets/GameScene.unity" }, locationPathName = output,
                target = BuildTarget.WebGL, options = BuildOptions.None
            });
            ReadLatestBuild();
        }

        // Explicit batch readback only: recover the persisted report after a
        // long export outlives the live automation request. Does not build/save.
        public static void ReadLatestBuild() {
            var report = BuildReport.GetLatestReport();
            if (report == null) {
                Debug.LogError("[HalabessaQa] No persisted build report.");
                EditorApplication.Exit(1);
                return;
            }
            var summary = report.summary;
            var checkout = Path.GetFullPath(Path.Combine(Application.dataPath, "../../.."));
            var expected = Path.Combine(checkout, "build", "unity-spices-qa", "web");
            if (summary.platform != BuildTarget.WebGL ||
                !string.Equals(Path.GetFullPath(summary.outputPath).TrimEnd('/', '\\'),
                    expected.TrimEnd('/', '\\'), StringComparison.OrdinalIgnoreCase)) {
                Debug.LogError("[HalabessaQa] Latest report is not the isolated WebGL check.");
                EditorApplication.Exit(2);
                return;
            }
            var verdict = new BuildVerdict {
                target = summary.platform.ToString(), result = summary.result.ToString(),
                output = summary.outputPath, finishedUtc = summary.buildEndedAt.ToUniversalTime().ToString("o"),
                errors = summary.totalErrors, warnings = summary.totalWarnings,
                bytes = summary.totalSize, seconds = summary.totalTime.TotalSeconds
            };
            var diagnostics = new System.Collections.Generic.List<string>();
            foreach (var step in report.steps) foreach (var message in step.messages) {
                if (message.type == LogType.Warning || message.type == LogType.Error ||
                    message.type == LogType.Exception || message.type == LogType.Assert)
                    diagnostics.Add(message.type + ": " + message.content);
            }
            verdict.diagnostics = diagnostics.ToArray();
            var json = JsonUtility.ToJson(verdict, true);
            File.WriteAllText(Path.Combine(checkout, "build", "unity-card-juice-web-build-report.json"), json);
            Debug.Log("[HalabessaQa] Build readback: " + json);
            EditorApplication.Exit(summary.result == BuildResult.Succeeded && summary.totalErrors == 0 ? 0 : 1);
        }

        public static void InstallPipeline() {
            Debug.Log("[HalabessaQa] Installing approved com.unity.pipeline@0.8.0-exp.1");
            request = Client.Add("com.unity.pipeline@0.8.0-exp.1");
            deadline = EditorApplication.timeSinceStartup + 600;
            EditorApplication.update += Poll;
        }

        private static void Poll() {
            if (request == null) return;
            if (!request.IsCompleted) {
                if (EditorApplication.timeSinceStartup <= deadline) return;
                EditorApplication.update -= Poll;
                Debug.LogError("[HalabessaQa] Package resolution timed out.");
                EditorApplication.Exit(2);
                return;
            }
            EditorApplication.update -= Poll;
            if (request.Status == StatusCode.Success) {
                Debug.Log("[HalabessaQa] Installed " + request.Result.packageId);
                EditorApplication.Exit(0);
            } else {
                Debug.LogError("[HalabessaQa] Package resolution failed: " + request.Error?.message);
                EditorApplication.Exit(1);
            }
        }
    }
}
