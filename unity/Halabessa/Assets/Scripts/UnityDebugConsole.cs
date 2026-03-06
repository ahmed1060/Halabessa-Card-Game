using UnityEngine;
using UnityEngine.Networking;
using System.Collections;
using System.Collections.Generic;

public class UnityDebugConsole : MonoBehaviour {
    private List<string> logs = new List<string>();
    private bool isVisible = false;
    
    void OnEnable() {
        Application.logMessageReceived += HandleLog;
    }

    void OnDisable() {
        Application.logMessageReceived -= HandleLog;
    }

    void HandleLog(string logString, string stackTrace, LogType type) {
        logs.Insert(0, "[" + type + "] " + logString);
        if (logs.Count > 20) logs.RemoveAt(20);
        
        // Also send to Flutter
        UnityBridge.Instance.NotifyFlutter("DEBUG_LOG", logString);
    }

    public void ToggleVisibility() {
        isVisible = !isVisible;
    }

    void OnGUI() {
        if (!isVisible) return;
        
        GUI.backgroundColor = new Color(0, 0, 0, 0.8f);
        GUILayout.BeginArea(new Rect(10, 10, Screen.width * 0.4f, Screen.height * 0.3f));
        GUILayout.Label("Unity Debug Console", GUI.skin.box);
        foreach (var log in logs) {
            GUILayout.Label(log);
        }
        GUILayout.EndArea();
    }
}
