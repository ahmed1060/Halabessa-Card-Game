using UnityEngine;
using DG.Tweening;
using System.Collections.Generic;
using FlutterUnityIntegration;

public class CardAnimator : MonoBehaviour {
    public static CardAnimator Instance;
    
    void Awake() {
        Instance = this;
    }
    
    public void MoveCardToBoard(GameObject card, Vector3 worldPosition) {
        card.transform.DOMove(worldPosition, 0.5f)
            .SetEase(Ease.OutQuad)
            .OnComplete(() => {
                // Potential "bounce" or "thud" effect
                card.transform.DOPunchScale(new Vector3(0.1f, 0.1f, 0.1f), 0.2f);
            });
    }
    
    public void CaptureCards(List<GameObject> cards, Vector3 teamStackPosition) {
        Sequence captureSeq = DOTween.Sequence();
        
        foreach (var card in cards) {
            captureSeq.Join(card.transform.DOMove(teamStackPosition, 0.6f).SetEase(Ease.InBack));
            captureSeq.Join(card.transform.DORotate(new Vector3(0, 0, 180), 0.6f)); // Flip face down
        }
        
        captureSeq.OnComplete(() => {
            foreach (var card in cards) {
                card.SetActive(false); // Or return to pool
            }
            UnityMessageManager.Instance.SendMessageToFlutter("ANIMATION_COMPLETE:CAPTURE");
        });
    }
}
