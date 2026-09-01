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
    private string activeSkinId;

    void Awake() {
        Instance = this;
        skinDict = new Dictionary<string, CardSkin>();
        foreach (var skin in availableSkins) {
            skinDict[skin.skinId] = skin;
        }
    }

    // Resolves the skin newly spawned cards should render with: whatever
    // Flutter last selected via UPDATE_SKINS, falling back to the first
    // configured skin so a card still gets a texture before any selection
    // ever arrives (see UnityBridge.HandleSyncState).
    public CardSkin GetActiveSkin() {
        if (activeSkinId != null && skinDict.TryGetValue(activeSkinId, out var skin)) {
            return skin;
        }
        return availableSkins != null && availableSkins.Count > 0 ? availableSkins[0] : null;
    }

    public void UpdateSkins(string skinId) {
        if (!skinDict.ContainsKey(skinId)) {
            Debug.LogWarning("Skin ID not found: " + skinId);
            return;
        }

        activeSkinId = skinId;
        CardSkin activeSkin = skinDict[skinId];

        var allCards = FindObjectsByType<CardInstance>(FindObjectsSortMode.None);
        foreach (var card in allCards) {
            card.ApplySkin(activeSkin);
        }
    }
}
