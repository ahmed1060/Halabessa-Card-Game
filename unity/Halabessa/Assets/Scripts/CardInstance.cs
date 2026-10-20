using UnityEngine;
using DG.Tweening;
using Studio.OverOne.DragMe.Data.Events;
using Studio.OverOne.DragMe.Data.Abstractions;

public class CardInstance : MonoBehaviour {
    public string cardId;
    public string rank;
    public string suit;
    public bool isFaceUp = true;
    
    [SerializeField] private MeshRenderer cardRenderer; // The Quad's renderer
    [SerializeField] private Transform shadowTransform;
    [SerializeField] private Texture2D frontTexture;
    [SerializeField] private Texture2D backTexture;
    private Material ownedFaceMaterial, ownedShadowMaterial;

    void Awake() {
        if (cardRenderer == null) cardRenderer = GetComponent<MeshRenderer>();
        if (shadowTransform == null) shadowTransform = transform.Find("Shadow");
        if (shadowTransform != null) shadowTransform.gameObject.SetActive(true);
        var mesh = Resources.Load<Mesh>("HalabessaCards/CardMesh");
        var material = Resources.Load<Material>("HalabessaCards/CardFaceMaterial");
        if (mesh != null && material != null && cardRenderer != null) {
            GetComponent<MeshFilter>().sharedMesh = mesh;
            var collider = GetComponent<MeshCollider>();
            if (collider != null) collider.sharedMesh = mesh;
            ownedFaceMaterial = new Material(material);
            cardRenderer.sharedMaterial = ownedFaceMaterial;
            if (shadowTransform != null) {
                var shadowRenderer = shadowTransform.GetComponent<MeshRenderer>();
                var shadowMesh = shadowTransform.GetComponent<MeshFilter>();
                if (shadowMesh != null) shadowMesh.sharedMesh = mesh;
                if (shadowRenderer != null) {
                    ownedShadowMaterial = new Material(material);
                    ownedShadowMaterial.color = new Color(0, 0, 0, .16f);
                    shadowRenderer.sharedMaterial = ownedShadowMaterial;
                    shadowRenderer.sortingOrder = -1;
                    shadowTransform.localPosition = new Vector3(.025f, -.025f, .015f);
                }
            }
        }
        
        // Setup for 3D Dragging (God Move)
        SetupDragging();
    }

    private void SetupDragging() {
        // Ensure Rigidbody for physics interaction
        Rigidbody rb = GetComponent<Rigidbody>();
        if (rb == null) {
            rb = gameObject.AddComponent<Rigidbody>();
            rb.isKinematic = true; // Stay in place unless dragged
            rb.useGravity = false;
        }

        // Ensure Collider
        if (GetComponent<Collider>() == null) {
            BoxCollider col = gameObject.AddComponent<BoxCollider>();
            col.size = new Vector3(1f, 1f, 0.1f);
        }

        // Add DragMe component
        Studio.OverOne.DragMe.Components.DragMe dragComp = GetComponent<Studio.OverOne.DragMe.Components.DragMe>();
        if (dragComp == null) {
            var config = Resources.Load<Studio.OverOne.DragMe.Data.DragMeConfig>("DragMe Hold 3d Config");
            if (config == null) {
                Debug.LogWarning("Card drag configuration is unavailable; leaving the existing card input untouched.");
                return;
            }
            // AddComponent runs Awake immediately on active objects. Configure
            // the existing drag library before its Awake reads the dependency.
            var wasActive = gameObject.activeSelf;
            if (wasActive) gameObject.SetActive(false);
            dragComp = gameObject.AddComponent<Studio.OverOne.DragMe.Components.DragMe>();
            dragComp.Config = config;

            // Listen for release to trigger "Play Card" (God Move)
            dragComp.e_Released.AddListener(OnCardReleased);
            if (wasActive) gameObject.SetActive(true);
        }
    }

    private void OnCardReleased(IReleasedEventData data) {
        // If the card is released in the "Table Area" (e.g. y > -0.5f)
        if (UnityBridge.Instance != null
            ? UnityBridge.Instance.IsTableDrop(transform.position)
            : transform.position.z > -1.5f) {
             // Debug.Log($"CardInstance: Card {cardId} played at {transform.position}");
             if (UnityBridge.Instance != null) {
                 UnityBridge.Instance.NotifyFlutter("PLAY_CARD", cardId);
             }
        } else {
             GetComponent<CardJuiceController>()?.ReturnHome();
             // Snap back to original hand position (handled by UnityBridge.HandleSyncState on next update)
             // Debug.Log("CardInstance: Card released but not played. Snapping back.");
        }
    }
    
    public void ApplySkin(DeckManager.CardSkin skin) {
        frontTexture = skin.frontTexture;
        backTexture = skin.backTexture;
        RefreshTexture();
    }

    private void RefreshTexture() {
        if (cardRenderer != null) {
            cardRenderer.material.mainTexture = isFaceUp ? frontTexture : backTexture;
            if (ownedShadowMaterial != null) ownedShadowMaterial.mainTexture = backTexture;
        }
    }

    public void SetFaceUp(bool faceUp) {
        isFaceUp = faceUp;
        RefreshTexture();
    }

    public void SetPresentationPosition(Vector3 position) {
        transform.position = position;
        var body = GetComponent<Rigidbody>();
        if (body != null) body.position = position;
        var drag = GetComponent<Studio.OverOne.DragMe.Components.DragMe>();
        if (drag != null) drag.DesiredPosition = position;
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
        SetPresentationPosition(transform.position);
        transform.DOMove(targetPosition, duration).SetEase(Ease.OutQuad)
            .OnUpdate(() => { if (this != null) SetPresentationPosition(transform.position); });
        
        // Add a slight "float" and shadow offset during flight
        if (shadowTransform != null) {
            shadowTransform.DOLocalMove(new Vector3(0.05f, -0.05f, 0.1f), duration / 2).SetLoops(2, LoopType.Yoyo);
        }
    }

    public void ShakeOnBasra() {
        transform.DOShakePosition(0.5f, 0.2f, 10, 90, false, true);
    }

    void OnDestroy() {
        // Essential DOTween cleanup (God Move)
        transform.DOKill();
        if (ownedFaceMaterial != null) Destroy(ownedFaceMaterial);
        if (ownedShadowMaterial != null) Destroy(ownedShadowMaterial);
    }
}
