using System;
using System.Collections;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.Events;
using DG.Tweening;

/// Managed hand input forwards intents only; Flutter still validates every move.
public class CardJuiceController : MonoBehaviour, IPointerEnterHandler,
    IPointerExitHandler, IPointerDownHandler, IPointerUpHandler,
    IPointerClickHandler, IBeginDragHandler, IDragHandler, IEndDragHandler {
    public UnityEvent OnHover = new UnityEvent();
    public UnityEvent OnGrab = new UnityEvent();
    public UnityEvent OnSlam = new UnityEvent();
    public UnityEvent OnReturn = new UnityEvent();
    public bool ReducedMotion;
    public bool Managed;
    public int BaseSortingOrder;
    private Transform visual;
    private MeshRenderer face;
    private Transform shadow;
    private Vector3 home, velocity, scaleVelocity;
    private Quaternion homeRotation;
    private Vector2 dragVelocity;
    private bool peek, dragging, animating;
    private Coroutine returning;
    private Tween punch;
    private bool localHand;
    private int? pointer;
    private Plane dragPlane;
    private Vector3 pointerOffset;
    private float externalDrag;
    public void SetHandPose(bool raised, float dragFraction, float speed) {
        if (!Managed || !localHand || animating) return;
        peek = raised; externalDrag = Mathf.Clamp(dragFraction, -.5f, .25f);
        dragVelocity = new Vector2(0, speed);
    }

    public void ConfigureInput(bool hand) {
        localHand = hand;
        // One input owner. The old DragMe path remains available to legacy
        // snapshots, but must not move a root owned by this managed renderer.
        var legacy = GetComponent<Studio.OverOne.DragMe.Components.DragMe>();
        if (legacy != null) legacy.enabled = !Managed;
        if (!hand) { pointer = null; dragging = false; peek = false; }
    }
    private bool CanInteract => Managed && localHand && !animating &&
        UnityBridge.Instance != null && UnityBridge.Instance.CanSubmitVisualIntent;

    void Awake() {
        var source = GetComponent<MeshRenderer>();
        var mesh = GetComponent<MeshFilter>();
        if (source == null || mesh == null) return;
        visual = new GameObject("CardVisual").transform;
        visual.SetParent(transform, false);
        visual.gameObject.AddComponent<MeshFilter>().sharedMesh = mesh.sharedMesh;
        face = visual.gameObject.AddComponent<MeshRenderer>();
        face.sharedMaterials = source.materials;
        face.shadowCastingMode = source.shadowCastingMode;
        face.receiveShadows = source.receiveShadows;
        source.enabled = false;
        shadow = transform.Find("Shadow");
        if (shadow != null) { shadow.DOKill(); shadow.SetParent(visual, false); }
        RememberHome(transform.position, transform.rotation);
    }

    public void RememberHome(Vector3 position, Quaternion rotation) {
        home = position; homeRotation = rotation;
    }
    private void Position(Vector3 position) {
        var card = GetComponent<CardInstance>();
        if (card != null) card.SetPresentationPosition(position);
        else transform.position = position;
    }
    void LateUpdate() {
        if (!Managed || visual == null || animating) return;
        var targetScale = Vector3.one * (peek ? 1.2f : 1f);
        visual.localScale = ReducedMotion ? targetScale : Vector3.SmoothDamp(
            visual.localScale, targetScale, ref scaleVelocity, .07f, Mathf.Infinity, Time.unscaledDeltaTime);
        var target = new Vector3(0, (peek ? .06f : 0) - externalDrag, peek ? -.06f : 0);
        visual.localPosition = ReducedMotion ? target : Vector3.SmoothDamp(
            visual.localPosition, target, ref velocity, .06f, Mathf.Infinity, Time.unscaledDeltaTime);
        var tilt = ReducedMotion ? Vector3.zero : new Vector3(
            Mathf.Clamp(dragVelocity.y * .01f, -10, 10),
            Mathf.Clamp(-dragVelocity.x * .01f, -10, 10), 0);
        visual.localRotation = Quaternion.Slerp(visual.localRotation,
            Quaternion.Euler(tilt), 1 - Mathf.Exp(-22 * Time.unscaledDeltaTime));
        if (!dragging) dragVelocity = Vector2.Lerp(dragVelocity, Vector2.zero,
            1 - Mathf.Exp(-18 * Time.unscaledDeltaTime));
        face.sortingOrder = peek ? 100 : BaseSortingOrder;
    }
    public void OnPointerEnter(PointerEventData e) { if (CanInteract) { peek = true; OnHover.Invoke(); } }
    public void OnPointerExit(PointerEventData e) { if (!dragging) peek = false; }
    public void OnPointerDown(PointerEventData e) {
        if (!CanInteract || pointer.HasValue) return;
        pointer = e?.pointerId ?? -1;
        peek = true; OnGrab.Invoke(); UnityBridge.Instance?.NotifyFlutter("VISUAL_PICK");
    }
    public void OnPointerUp(PointerEventData e) {
        if (pointer != (e?.pointerId ?? -1)) return;
        peek = false;
        // Keep the pointer through EndDrag/Click (EventSystem sends Up first).
        if (e == null) pointer = null;
    }
    public void OnPointerClick(PointerEventData e) {
        if (pointer != (e?.pointerId ?? -1)) return;
        var wasDragging = dragging;
        pointer = null; peek = false;
        if (CanInteract && !wasDragging) UnityBridge.Instance.SubmitVisualIntent(GetComponent<CardInstance>());
    }
    public void OnBeginDrag(PointerEventData e) {
        if (!CanInteract || e == null || pointer != e.pointerId || Camera.main == null) return;
        dragPlane = new Plane(-Camera.main.transform.forward, transform.position);
        float distance;
        var ray = Camera.main.ScreenPointToRay(e.position);
        if (!dragPlane.Raycast(ray, out distance)) return;
        pointerOffset = transform.position - ray.GetPoint(distance);
        dragging = true;
    }
    public void OnDrag(PointerEventData e) {
        if (!dragging || e == null || pointer != e.pointerId || Camera.main == null) return;
        dragVelocity = e.delta / Mathf.Max(.001f, Time.unscaledDeltaTime);
        var ray = Camera.main.ScreenPointToRay(e.position);
        float distance;
        if (dragPlane.Raycast(ray, out distance)) Position(ray.GetPoint(distance) + pointerOffset);
    }
    public void OnEndDrag(PointerEventData e) {
        if (e == null || pointer != e.pointerId) return;
        var moved = dragging;
        pointer = null; dragging = false; peek = false;
        if (!moved) return;
        if (CanInteract && UnityBridge.Instance.IsTableDrop(transform.position) &&
            UnityBridge.Instance.SubmitVisualIntent(GetComponent<CardInstance>())) return;
        ReturnHome();
    }

    public IEnumerator Fly(Vector3 target, float duration, bool slam, Action beforeContact, Action impact = null) {
        CancelPose();
        animating = true;
        transform.DOKill();
        var start = transform.position;
        if (ReducedMotion || duration <= 0) {
            Position(target); beforeContact?.Invoke(); animating = false; yield break;
        }
        var elapsed = 0f; var contacted = false;
        while (elapsed < duration) {
            var t = Mathf.Clamp01(elapsed / duration);
            var eased = 1 - Mathf.Pow(1 - t, 3);
            Position(Vector3.LerpUnclamped(start, target, eased)
                + Vector3.up * Mathf.Sin(t * Mathf.PI) * .22f);
            if (visual != null) visual.localRotation = Quaternion.Euler(0,
                Mathf.Sin(t * Mathf.PI) * 7, Mathf.Sin(t * Mathf.PI) * -5);
            if (!contacted && elapsed >= duration - .03f) {
                contacted = true; beforeContact?.Invoke();
            }
            elapsed += Time.unscaledDeltaTime; yield return null;
        }
        Position(target);
        if (!contacted) beforeContact?.Invoke();
        if (slam) { OnSlam.Invoke(); yield return new WaitForSecondsRealtime(.05f); impact?.Invoke(); }
        if (visual != null && (slam || duration <= .22f)) {
            visual.localRotation = Quaternion.identity;
            punch = visual.DOPunchScale(new Vector3(slam ? .055f : .025f, -.025f, .025f), .12f, 1, .4f).SetUpdate(true);
            yield return punch.WaitForCompletion();
        }
        animating = false;
    }

    public void ReturnHome() {
        if (!Managed) return;
        CancelPose();
        returning = StartCoroutine(Return());
    }
    private IEnumerator Return() {
        animating = true; transform.DOKill(); OnReturn.Invoke();
        if (ReducedMotion) { Position(home); transform.rotation = homeRotation; }
        else {
            var sequence = DOTween.Sequence().SetUpdate(true);
            sequence.Join(transform.DOMove(home, .25f).SetEase(Ease.OutBack));
            sequence.Join(transform.DORotateQuaternion(homeRotation, .25f).SetEase(Ease.OutBack));
            sequence.OnUpdate(() => Position(transform.position));
            yield return sequence.WaitForCompletion();
        }
        animating = false; returning = null;
    }
    public void CancelPose() {
        if (returning != null) StopCoroutine(returning);
        returning = null; punch?.Kill(); punch = null;
        animating = false; dragging = false; peek = false; pointer = null;
        velocity = scaleVelocity = Vector3.zero; dragVelocity = Vector2.zero;
        externalDrag = 0;
        if (visual != null) { visual.DOKill(); visual.localPosition = Vector3.zero;
            visual.localRotation = Quaternion.identity; visual.localScale = Vector3.one; }
        if (face != null) face.sortingOrder = BaseSortingOrder;
    }
    void OnDisable() { CancelPose(); transform.DOKill(); }
    void OnDestroy() { CancelPose(); }
}
