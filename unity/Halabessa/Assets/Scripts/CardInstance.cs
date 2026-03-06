using UnityEngine;
using DG.Tweening;

public class CardInstance : MonoBehaviour {
    public string cardId;
    public string rank;
    public string suit;
    
    [SerializeField] private MeshRenderer frontRenderer;
    [SerializeField] private MeshRenderer backRenderer;
    
    public void ApplySkin(DeckManager.CardSkin skin) {
        if (frontRenderer != null) {
            frontRenderer.material.mainTexture = skin.frontTexture;
        }
        if (backRenderer != null) {
            backRenderer.material.mainTexture = skin.backTexture;
        }
    }

    public void PlayAnimation(Vector3 targetPosition, float duration = 0.5f) {
        if (AudioManager.Instance != null) AudioManager.Instance.PlayCardFly();
        transform.DOMove(targetPosition, duration).SetEase(Ease.OutQuad);
        transform.DORotate(new Vector3(0, 0, 0), duration); // Ensure face up
    }

    public void ShakeOnBasra() {
        transform.DOShakePosition(0.5f, 0.2f, 10, 90, false, true);
    }
}
