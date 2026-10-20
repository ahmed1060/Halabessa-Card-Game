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

    // Built-in faces are baked from Flutter's existing CardWidget. Custom
    // configured Unity skins keep their original path and are not replaced.
    public CardSkin GetSkinForCard(string cardId) {
        var configured = GetActiveSkin();
        // A fallback custom skin must not override an explicitly selected
        // built-in skin. Exact configured matches still retain their old path.
        if (configured != null && (activeSkinId == null || configured.skinId == activeSkinId)) return configured;
        var id = activeSkinId ?? "default_card";
        if (id != "default_card" && id != "neon_card" && id != "royal_card") return configured;
        var front = Resources.Load<Texture2D>("HalabessaCards/" + id + "/" + cardId);
        var back = Resources.Load<Texture2D>("HalabessaCards/" + id + "/back");
        return front != null && back != null ? new CardSkin {
            skinId = id, frontTexture = front, backTexture = back
        } : configured;
    }

    public void UpdateSkins(string skinId) {
        var builtIn = skinId == "default_card" || skinId == "neon_card" || skinId == "royal_card";
        if (!skinDict.ContainsKey(skinId) && (!builtIn || Resources.Load<Texture2D>("HalabessaCards/" + skinId + "/back") == null)) {
            Debug.LogWarning("Skin ID not found: " + skinId);
            return;
        }

        activeSkinId = skinId;

        var allCards = FindObjectsByType<CardInstance>(FindObjectsSortMode.None);
        foreach (var card in allCards) {
            var skin = GetSkinForCard(card.cardId);
            if (skin != null) card.ApplySkin(skin);
        }
    }
}
