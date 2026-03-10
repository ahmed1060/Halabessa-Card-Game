using UnityEngine;
using System;
using System.Collections.Generic;

public class DeckManager : MonoBehaviour {
    public static DeckManager Instance;

    [Serializable]
    public class CardSkin {
        public string skinId;
        public Texture2D frontTexture;
        public Texture2D backTexture;
    }

    public List<CardSkin> availableSkins;
    private Dictionary<string, CardSkin> skinDict;

    void Awake() {
        Instance = this;
        skinDict = new Dictionary<string, CardSkin>();
        foreach (var skin in availableSkins) {
            skinDict[skin.skinId] = skin;
        }
    }

    public void UpdateSkins(string skinId) {
        if (!skinDict.ContainsKey(skinId)) {
            Debug.LogWarning("Skin ID not found: " + skinId);
            return;
        }

        CardSkin activeSkin = skinDict[skinId];
        // In a real implementation, you would update the Material on the Card prefabs
        // or notify all active card instances to swap their textures.
        // Debug.Log("Unity: Updating all cards to use skin: " + skinId);
        
        // Example: Find all cards and update their materials
        // var allCards = FindObjectsOfType<CardInstance>();
        // foreach(var card in allCards) card.ApplySkin(activeSkin);
    }
}
