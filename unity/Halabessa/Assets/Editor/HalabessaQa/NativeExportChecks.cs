using System;
using System.IO;
using System.Collections.Generic;
using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEngine;

namespace HalabessaQa {
    // Opt-in qualification only. Never replaces embedded Flutter exports.
    public static class NativeExportChecks {
        [Serializable]
        private class Verdict {
            public string target, result, output;
            public int errors, warnings;
            public double seconds;
            public string[] diagnostics;
        }
        public static void Android() { Export(BuildTarget.Android, "android"); }
        public static void IOS() { Export(BuildTarget.iOS, "ios"); }
        private static void Export(BuildTarget target, string folder) {
            if (Application.isPlaying || EditorUserBuildSettings.activeBuildTarget != target)
                throw new Exception("Select the requested target before isolated export.");
            var checkout = Path.GetFullPath(Path.Combine(Application.dataPath, "../../.."));
            var output = Path.Combine(checkout, "build", "unity-spices-qa", folder);
            Directory.CreateDirectory(output);
            var previousExport = EditorUserBuildSettings.exportAsGoogleAndroidProject;
            try {
                if (target == BuildTarget.Android) EditorUserBuildSettings.exportAsGoogleAndroidProject = true;
                var report = BuildPipeline.BuildPlayer(new BuildPlayerOptions {
                    scenes = new[] { "Assets/GameScene.unity" }, target = target,
                    locationPathName = output, options = BuildOptions.None
                });
                var summary = report.summary;
                var diagnostics = new List<string>();
                foreach (var step in report.steps) foreach (var message in step.messages) {
                    if (message.type != LogType.Log)
                        diagnostics.Add(message.type + ": " + message.content);
                }
                var verdict = new Verdict {
                    target = target.ToString(), result = summary.result.ToString(), output = output,
                    errors = summary.totalErrors, warnings = summary.totalWarnings,
                    seconds = summary.totalTime.TotalSeconds, diagnostics = diagnostics.ToArray()
                };
                File.WriteAllText(Path.Combine(checkout, "build", "unity-card-juice-" + folder + "-export.json"),
                    JsonUtility.ToJson(verdict, true));
                if (summary.result != BuildResult.Succeeded || summary.totalErrors != 0)
                    throw new Exception("Isolated " + target + " export failed; inspect its build report.");
#if UNITY_IOS
                if (target == BuildTarget.iOS) XcodePostBuild.PostBuild(target, output);
#endif
                Debug.Log("[HalabessaQa] Isolated " + target + " export succeeded: " + output);
            } finally {
                EditorUserBuildSettings.exportAsGoogleAndroidProject = previousExport;
            }
        }
    }
}
