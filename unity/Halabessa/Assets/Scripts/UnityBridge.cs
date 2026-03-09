using UnityEngine;
using FlutterUnityIntegration;
using System;
using System.Runtime.InteropServices;
using System.Collections.Generic;

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
        // FORCE TRANSPARENCY AT RUNTIME (God Move)
        if (Camera.main != null) {
            Camera.main.clearFlags = CameraClearFlags.SolidColor;
            Camera.main.backgroundColor = new Color(0, 0, 0, 0);
            Debug.Log("UnityBridge: Forced Camera transparency (Alpha 0)");
        }
        NotifyFlutter("UNITY_READY", "Unity initialized");
    }
    
    // Proxy for console visibility to avoid "object not found" routing issues
    public void ToggleConsole(string dummy) {
        UnityDebugConsole console = FindObjectOfType<UnityDebugConsole>(true);
        if (console != null) {
            console.ToggleVisibility();
        } else {
            Debug.LogWarning("UnityBridge: UnityDebugConsole script not found in scene!");
        }
    }

    // Called from Flutter via _unityWidgetController.postMessage('UnityBridge', 'OnFlutterMessage', json)
    public void OnFlutterMessage(string messageJson) {
        Debug.Log("UnityBridge Received: " + messageJson);
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

        // 1. Destroy cards that are no longer on the board
        List<string> newBoardIds = new List<string>();
        foreach(var c in boardCards) {
            newBoardIds.Add(c.id ?? (c.suit + "_" + c.rank)); // Fallback ID creation
        }

        List<string> keysToRemove = new List<string>();
        foreach(var kvp in activeCards) {
            if (!newBoardIds.Contains(kvp.Key)) {
                Destroy(kvp.Value);
                keysToRemove.Add(kvp.Key);
            }
        }
        foreach(var k in keysToRemove) activeCards.Remove(k);

        // 2. Spawn and Position new cards
        float startX = -1.5f; // Slightly more compact
        float spacing = 1.0f;
        
        for (int i = 0; i < boardCards.Count; i++) {
            CardJson cardData = boardCards[i];
            string cardId = cardData.id ?? (cardData.suit + "_" + cardData.rank);

            if (!activeCards.ContainsKey(cardId)) {
                Debug.Log($"UnityBridge: Attempting to spawn card {cardId}");
                
                // Spawn a new card
                GameObject newCard = Instantiate(cardPrefab);
                newCard.name = "Card_" + cardId;
                
                // Ensure scale is correct (important if prefab is tiny/huge)
                newCard.transform.localScale = Vector3.one * 1.5f; 
                
                // FLATTEN ON TABLE (God Move)
                newCard.transform.localRotation = Quaternion.Euler(90, 0, 0);
                
                // Target position on the table (Moved Z closer to camera for visibility)
                Vector3 targetPos = new Vector3(startX + (i * spacing), 0.1f, -1.0f); 
                
                CardInstance cardScript = newCard.GetComponent<CardInstance>();
                if (cardScript != null) {
                    Debug.Log($"UnityBridge: Customizing card {cardId}");
                    // Start flying from off-screen
                    newCard.transform.position = new Vector3(0, 5f, 5f); 
                    cardScript.PlayAnimation(targetPos, 0.5f + (i * 0.1f));
                } else {
                    Debug.LogWarning($"UnityBridge: CardInstance script missing on {newCard.name}. Using static position.");
                    newCard.transform.position = targetPos;
                }
                
                activeCards.Add(cardId, newCard);
                Debug.Log($"UnityBridge: SUCCESS - Card {cardId} flying to {targetPos}");
            }
        }

        // 3. Spawn and Position Hand Cards (Premium 3D Hand)
        float handBaseZ = -2.5f; // Closer to camera
        float handY = -1.5f; // Bottom of screen (adjusted for camera view)
        float handSpacing = 0.6f;
        float handStartX = -((handCards.Count - 1) * handSpacing) / 2f;

        for (int i = 0; i < handCards.Count; i++) {
            CardJson cardData = handCards[i];
            string cardId = cardData.id ?? (cardData.suit + "_" + cardData.rank);
            
            if (!activeCards.ContainsKey(cardId)) {
                GameObject newCard = Instantiate(cardPrefab);
                newCard.name = "HandCard_" + cardId;
                newCard.transform.localScale = Vector3.one * 1.5f;
                newCard.transform.localRotation = Quaternion.Euler(60, 0, 0); 
                
                Vector3 targetPos = new Vector3(handStartX + (i * handSpacing), handY, handBaseZ);
                newCard.transform.position = new Vector3(targetPos.x, targetPos.y - 2f, targetPos.z); 
                
                CardInstance cardScript = newCard.GetComponent<CardInstance>();
                if (cardScript != null) {
                    cardScript.cardId = cardId;
                    cardScript.rank = cardData.rank;
                    cardScript.suit = cardData.suit;
                    cardScript.PlayAnimation(targetPos, 0.6f);
                } else {
                    newCard.transform.position = targetPos;
                }
                
                activeCards.Add(cardId, newCard);
            } else {
                Vector3 targetPos = new Vector3(handStartX + (i * handSpacing), handY, handBaseZ);
                GameObject existing = activeCards[cardId];
                existing.transform.DOMove(targetPos, 0.3f);
            }
        }
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
