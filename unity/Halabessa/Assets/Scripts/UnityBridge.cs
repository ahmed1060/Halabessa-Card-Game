using UnityEngine;
using FlutterUnityIntegration;
using System;
using System.Runtime.InteropServices;
using System.Collections.Generic;

public class UnityBridge : MonoBehaviour {
    public static UnityBridge Instance;
    
#if UNITY_WEBGL && !UNITY_EDITOR
    [DllImport("__Internal")]
    private static extern void PostToFlutter(string message);
#endif

    void Awake() {
        if (Instance == null) Instance = this;
    }

    void Start() {
        NotifyFlutter("UNITY_READY", "Unity initialized");
    }
    
    // Called from Flutter via _unityWidgetController.postMessage('UnityBridge', 'OnFlutterMessage', json)
    public void OnFlutterMessage(string message) {
        // ... (existing logic)
    }

    // ... (HandleSyncState, SpawnCard, HandlePlayCard, TriggerBasra)

    public void NotifyFlutter(string eventName, string data = "") {
        string message = string.Format("{{\"event\": \"{0}\", \"data\": \"{1}\"}}", eventName, data);
#if UNITY_WEBGL && !UNITY_EDITOR
        PostToFlutter(message);
#else
        UnityMessageManager.Instance.SendMessageToFlutter(message);
#endif
    }

    [Serializable]
    public class MessageData {
        public string type;
        public string cardId;
        public float x;
        public float y;
        public string skinId;
        public List<CardJson> board;
        public float duration;
        public string mode;
    }

    [Serializable]
    public class CardJson {
        public string id;
        public string rank;
        public string suit;
    }
}
