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
                // Professional "thud" effect and shadow settling
                card.transform.DOPunchScale(new Vector3(0.08f, 0.08f, 0.08f), 0.3f, 10, 1f);
            });
    }
    
    public void CaptureCards(List<GameObject> cards, Vector3 teamStackPosition) {
        Sequence captureSeq = DOTween.Sequence();
        
        foreach (var card in cards) {
            CardInstance instance = card.GetComponent<CardInstance>();
            captureSeq.Join(card.transform.DOMove(teamStackPosition + new Vector3(0, 0, -0.1f), 0.6f).SetEase(Ease.InBack));
            
            if (instance != null) {
                // Use the new flip animation for a professional look
                instance.PlayFlipAnimation(false, 0.6f);
            } else {
                captureSeq.Join(card.transform.DORotate(new Vector3(0, 0, 180), 0.6f));
            }
        }
        
        captureSeq.OnComplete(() => {
            foreach (var card in cards) {
                card.SetActive(false); // Or return to pool
            }
            UnityMessageManager.Instance.SendMessageToFlutter("ANIMATION_COMPLETE:CAPTURE");
        });
    }
}
