using UnityEngine;
using UnityEngine.Networking;
using System.Collections;
using System.Collections.Generic;

public class UnityDebugConsole : MonoBehaviour {
    private List<string> logs = new List<string>();
    private bool isVisible = false;
    
    void OnEnable() {
#if UNITY_EDITOR || DEBUG
        Application.logMessageReceived += HandleLog;
#endif
    }

    void OnDisable() {
#if UNITY_EDITOR || DEBUG
        Application.logMessageReceived -= HandleLog;
#endif
    }

    void HandleLog(string logString, string stackTrace, LogType type) {
        logs.Insert(0, "[" + type + "] " + logString);
        if (logs.Count > 20) logs.RemoveAt(20);
        
        // Also send to Flutter
        UnityBridge.Instance.NotifyFlutter("DEBUG_LOG", logString);
    }

    public void ToggleVisibility() {
#if UNITY_EDITOR || DEBUG
        isVisible = !isVisible;
#endif
    }

    void OnGUI() {
#if UNITY_EDITOR || DEBUG
        if (!isVisible) return;
        
        GUI.backgroundColor = new Color(0, 0, 0, 0.8f);
        GUILayout.BeginArea(new Rect(10, 10, Screen.width * 0.4f, Screen.height * 0.3f));
        GUILayout.Label("Unity Debug Console", GUI.skin.box);
        foreach (var log in logs) {
            GUILayout.Label(log);
        }
        GUILayout.EndArea();
#endif
    }
}
