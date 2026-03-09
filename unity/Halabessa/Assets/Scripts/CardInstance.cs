using UnityEngine;
using DG.Tweening;

public class CardInstance : MonoBehaviour {
    public string cardId;
    public string rank;
    public string suit;
    public bool isFaceUp = true;
    
    [SerializeField] private MeshRenderer cardRenderer; // The Quad's renderer
    [SerializeField] private Transform shadowTransform;
    [SerializeField] private Texture2D frontTexture;
    [SerializeField] private Texture2D backTexture;

    void Awake() {
        if (cardRenderer == null) cardRenderer = GetComponent<MeshRenderer>();
        if (shadowTransform != null) shadowTransform.gameObject.SetActive(true);
    }
    
    public void ApplySkin(DeckManager.CardSkin skin) {
        frontTexture = skin.frontTexture;
        backTexture = skin.backTexture;
        RefreshTexture();
    }

    private void RefreshTexture() {
        if (cardRenderer != null) {
            cardRenderer.material.mainTexture = isFaceUp ? frontTexture : backTexture;
        }
    }

    public void SetFaceUp(bool faceUp) {
        isFaceUp = faceUp;
        RefreshTexture();
    }

    public void PlayFlipAnimation(bool targetFaceUp, float duration = 0.4f) {
        // Professional mid-flip texture swap at 90 degrees
        transform.DORotate(new Vector3(0, 90, 0), duration / 2)
            .SetEase(Ease.InQuad)
            .OnComplete(() => {
                isFaceUp = targetFaceUp;
                RefreshTexture();
                transform.DORotate(new Vector3(0, targetFaceUp ? 180 : 0, 0), duration / 2) // Quads are often reversed, adjusting for 180 flip
                    .SetEase(Ease.OutQuad);
            });
    }

    public void PlayAnimation(Vector3 targetPosition, float duration = 0.5f) {
        if (AudioManager.Instance != null) AudioManager.Instance.PlayCardFly();
        transform.DOMove(targetPosition, duration).SetEase(Ease.OutQuad);
        
        // Add a slight "float" and shadow offset during flight
        if (shadowTransform != null) {
            shadowTransform.DOLocalMove(new Vector3(0.05f, -0.05f, 0.1f), duration / 2).SetLoops(2, LoopType.Yoyo);
        }
    }

    public void ShakeOnBasra() {
        transform.DOShakePosition(0.5f, 0.2f, 10, 90, false, true);
    }
}
