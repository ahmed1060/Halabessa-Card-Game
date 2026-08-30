using UnityEngine;
using FlutterUnityIntegration;
using System;
using System.Runtime.InteropServices;
using System.Collections.Generic;
using DG.Tweening;

public class UnityBridge : MonoBehaviour {
    public static UnityBridge Instance;
    
    // The prefab we generated in our AutoSceneBuilder
    private GameObject cardPrefab;

    // Keep track of spawned cards by ID to animate them later
    private Dictionary<string, GameObject> activeCards = new Dictionary<string, GameObject>();

#if UNITY_WEBGL && !UNITY_EDITOR
    [DllImport("__Internal")]
    private static extern void PostToFlutter(string message);
#endif

    void Awake() {
        if (Instance == null) Instance = this;
        // Load the dummy prefab from resources
        cardPrefab = Resources.Load<GameObject>("CardPrefab");
    }

    void Start() {
#if UNITY_WEBGL && !UNITY_EDITOR
        WebGLInput.captureAllKeyboardInput = false;
#endif
        // FORCE TRANSPARENCY AT RUNTIME (God Move)
        if (Camera.main != null) {
            Camera.main.clearFlags = CameraClearFlags.SolidColor;
            Camera.main.backgroundColor = new Color(0, 0, 0, 0);
            // Debug.Log("UnityBridge: Forced Camera transparency (Alpha 0)");
        }
        NotifyFlutter("UNITY_READY", "Unity initialized");
    }
    
    // Proxy for console visibility to avoid "object not found" routing issues
    public void ToggleConsole(string dummy) {
        UnityDebugConsole console = FindFirstObjectByType<UnityDebugConsole>(FindObjectsInactive.Include);
        if (console != null) {
            console.ToggleVisibility();
        }
        // Silently no-op if console component is absent (production build)
    }

    // Called from Flutter via _unityWidgetController.postMessage('UnityBridge', 'OnFlutterMessage', json)
    public void OnFlutterMessage(string messageJson) {
        // Silenced chatty log for production (God Move)
        try {
            MessageData data = JsonUtility.FromJson<MessageData>(messageJson);
            
            if (data.type == "SYNC_STATE") {
                HandleSyncState(data.board, data.handCards);
            } else if (data.type == "START_TIMER") {
                if (TurnTimer.Instance != null) {
                    TurnTimer.Instance.StartTimer(data.duration);
                }
            } else if (data.type == "SET_MODE") {
                GameStateManager.Instance.SetMode(data.mode);
            }
        } catch (Exception e) {
            Debug.LogError("Error parsing Flutter message: " + e.Message);
        }
    }

    private void HandleSyncState(List<CardJson> boardCards, List<CardJson> handCards) {
        if (cardPrefab == null) {
            Debug.LogError("CardPrefab is missing from Resources folder! Cannot spawn cards.");
            return;
        }

        // 1. Identify all desired cards and their target positions
        HashSet<string> desiredIds = new HashSet<string>();
        Dictionary<string, Vector3> targetPositions = new Dictionary<string, Vector3>();
        Dictionary<string, bool> isOnHand = new Dictionary<string, bool>();

        // Prep Board Positions
        float boardStartX = -1.5f;
        float boardSpacing = 1.0f;
        for (int i = 0; i < boardCards.Count; i++) {
            string id = GetCardId(boardCards[i]);
            desiredIds.Add(id);
            targetPositions[id] = new Vector3(boardStartX + (i * boardSpacing), 0.1f, -1.0f);
            isOnHand[id] = false;
        }

        // Prep Hand Positions
        float handBaseZ = -2.5f;
        float handY = -1.5f;
        float handSpacing = 0.6f;
        float handStartX = -((handCards.Count - 1) * handSpacing) / 2f;
        for (int i = 0; i < handCards.Count; i++) {
            string id = GetCardId(handCards[i]);
            desiredIds.Add(id);
            targetPositions[id] = new Vector3(handStartX + (i * handSpacing), handY, handBaseZ);
            isOnHand[id] = true;
        }

        // 2. Cleanup: Remove cards no longer in the state
        List<string> keysToRemove = new List<string>();
        foreach (var kvp in activeCards) {
            if (!desiredIds.Contains(kvp.Key)) {
                if (kvp.Value != null) {
                    kvp.Value.transform.DOKill();
                    Destroy(kvp.Value);
                }
                keysToRemove.Add(kvp.Key);
            }
        }
        foreach (var k in keysToRemove) activeCards.Remove(k);

        // 3. Update Existing and Spawn New
        foreach (var id in desiredIds) {
            Vector3 targetPos = targetPositions[id];
            bool inHand = isOnHand[id];

            if (!activeCards.ContainsKey(id)) {
                // Spawn new
                GameObject newCard = Instantiate(cardPrefab);
                newCard.name = (inHand ? "Hand_" : "Board_") + id;
                newCard.transform.localScale = Vector3.one * 1.5f;
                
                // Initial position (coming from above)
                newCard.transform.position = new Vector3(targetPos.x, targetPos.y + 5f, targetPos.z + 5f);
                newCard.transform.localRotation = Quaternion.Euler(inHand ? -60 : -90, 0, 0);

                Debug.Log($"[PRODUCTION_FIX] Spawned card: {id} at {newCard.transform.position}");

                CardInstance cardScript = newCard.GetComponent<CardInstance>();
                if (cardScript != null) {
                    cardScript.cardId = id;
                    // Find card data for metadata
                    CardJson meta = boardCards.Find(c => GetCardId(c) == id) ?? handCards.Find(c => GetCardId(c) == id);
                    if (meta != null) {
                        cardScript.rank = meta.rank;
                        cardScript.suit = meta.suit;
                    }
                    Debug.Log($"[PRODUCTION_FIX] Animating card {id} flying to {targetPos}");
                    cardScript.PlayAnimation(targetPos, 0.6f);
                } else {
                    newCard.transform.position = targetPos;
                }
                activeCards.Add(id, newCard);
            } else {
                // Update existing
                GameObject existing = activeCards[id];
                existing.transform.DOMove(targetPos, 0.4f).SetEase(Ease.OutQuad);
                existing.transform.DORotate(new Vector3(inHand ? -60 : -90, 0, 0), 0.4f);
            }
        }
    }

    private string GetCardId(CardJson c) {
        if (!string.IsNullOrEmpty(c.id)) return c.id;
        return (c.suit ?? "nil") + "_" + (c.rank ?? "nil");
    }

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
        public List<CardJson> handCards;
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
