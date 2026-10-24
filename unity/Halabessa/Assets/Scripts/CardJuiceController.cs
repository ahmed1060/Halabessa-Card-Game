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
    public bool RefinedHand;
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
    private bool queuedSelection, slamSelection;
    private LineRenderer selectionRim, slamRim;
    private Material rimMaterial;
    public Vector3 RenderedCenter => visual != null ? visual.position : transform.position;
    public void PreserveReleasePose() {
        var position = RenderedCenter;
        var scale = visual != null ? Vector3.Scale(transform.localScale, visual.localScale) : transform.localScale;
        CancelPose(); Position(position);
        transform.localScale = scale;
    }
    public void SetHandSelection(bool queued, bool slam) {
        if (!Managed || !localHand) return;
        queuedSelection = queued; slamSelection = slam;
    }
    public void SetHandPose(bool raised, float dragFraction, float speed) {
        if (!Managed || !localHand) return;
        peek = raised; externalDrag = Mathf.Clamp(dragFraction, -.5f, .25f);
        dragVelocity = new Vector2(0, speed);
    }

    public void ConfigureInput(bool hand) {
        localHand = hand;
        // One input owner. The old DragMe path remains available to legacy
        // snapshots, but must not move a root owned by this managed renderer.
        var legacy = GetComponent<Studio.OverOne.DragMe.Components.DragMe>();
        if (legacy != null) legacy.enabled = !Managed;
        if (!hand) { pointer = null; dragging = false; peek = false;
            queuedSelection = slamSelection = false; SetRims(false, false); }
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
        var raised = peek || queuedSelection || slamSelection;
        var zoom = RefinedHand ? peek : raised;
        SetRims(!RefinedHand && (queuedSelection || slamSelection), !RefinedHand && slamSelection);
        var targetScale = Vector3.one * (zoom ? 1.2f : 1f);
        visual.localScale = ReducedMotion ? targetScale : Vector3.SmoothDamp(
            visual.localScale, targetScale, ref scaleVelocity, .07f, Mathf.Infinity, Time.unscaledDeltaTime);
        var target = new Vector3(0, (zoom ? .06f : 0) - externalDrag, zoom ? -.06f : 0);
        visual.localPosition = ReducedMotion ? target : Vector3.SmoothDamp(
            visual.localPosition, target, ref velocity, .06f, Mathf.Infinity, Time.unscaledDeltaTime);
        var tilt = ReducedMotion ? Vector3.zero : new Vector3(
            Mathf.Clamp(dragVelocity.y * .01f, -10, 10),
            Mathf.Clamp(-dragVelocity.x * .01f, -10, 10), 0);
        visual.localRotation = Quaternion.Slerp(visual.localRotation,
            Quaternion.Euler(tilt), 1 - Mathf.Exp(-22 * Time.unscaledDeltaTime));
        if (!dragging) dragVelocity = Vector2.Lerp(dragVelocity, Vector2.zero,
            1 - Mathf.Exp(-18 * Time.unscaledDeltaTime));
        face.sortingOrder = raised ? 100 : BaseSortingOrder;
        if (selectionRim != null) selectionRim.sortingOrder = face.sortingOrder + 1;
        if (slamRim != null) slamRim.sortingOrder = face.sortingOrder + 2;
    }
    private void SetRims(bool selected, bool slam) {
        if (selected && selectionRim == null && visual != null) {
            var shader = Shader.Find("Sprites/Default");
            if (shader == null) return;
            rimMaterial = new Material(shader);
            selectionRim = CreateRim("PrivateSelectionRim", .365f, .515f);
            slamRim = CreateRim("PrivateSlamRim", .342f, .492f);
        }
        if (selectionRim != null) selectionRim.enabled = selected;
        if (slamRim != null) slamRim.enabled = selected && slam;
    }
    private LineRenderer CreateRim(string name, float halfWidth, float halfHeight) {
        var go = new GameObject(name); go.transform.SetParent(visual, false);
        var line = go.AddComponent<LineRenderer>();
        line.useWorldSpace = false; line.loop = true; line.positionCount = 32;
        line.sharedMaterial = rimMaterial; line.widthMultiplier = .012f;
        line.startColor = line.endColor = new Color(1f, .79f, .33f);
        line.numCapVertices = line.numCornerVertices = 4;
        // Rounded rectangle follows the imported .7 x 1 card, not its collider.
        const float radius = .035f;
        for (var corner = 0; corner < 4; corner++) {
            var center = new Vector2((corner == 0 || corner == 3 ? 1 : -1) * (halfWidth - radius),
                (corner < 2 ? 1 : -1) * (halfHeight - radius));
            for (var point = 0; point < 8; point++) {
                var angle = (corner * 90 + point * 90f / 7) * Mathf.Deg2Rad;
                line.SetPosition(corner * 8 + point, new Vector3(center.x + Mathf.Cos(angle) * radius,
                    center.y + Mathf.Sin(angle) * radius, -.004f));
            }
        }
        line.enabled = false;
        return line;
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

    public IEnumerator Fly(Vector3 target, float duration, bool slam, Action beforeContact, Action impact = null, bool gesture = false, Vector3? releasedScale = null) {
        CancelPose();
        animating = true;
        transform.DOKill();
        var start = transform.position;
        var targetScale = transform.localScale;
        var releaseScale = releasedScale ?? targetScale;
        if (releasedScale.HasValue) transform.localScale = releaseScale;
        if (ReducedMotion || duration <= 0) {
            Position(target); transform.localScale = targetScale; beforeContact?.Invoke(); animating = false; yield break;
        }
        if (gesture) {
            var windup = 0f;
            var anticipation = RefinedHand ? .14f : .1f;
            while (windup < anticipation) {
                var t = Mathf.Clamp01(windup / anticipation);
                if (visual != null) { visual.localScale = Vector3.one * (1 + (RefinedHand ? .6f : .2f) * t);
                    visual.localPosition = new Vector3(0, (RefinedHand ? .22f : .1f) * t, -.06f * t); }
                windup += Time.unscaledDeltaTime; yield return null;
            }
        }
        var elapsed = 0f; var contacted = false;
        while (elapsed < duration) {
            var t = Mathf.Clamp01(elapsed / duration);
            var eased = gesture ? t * t * t : 1 - Mathf.Pow(1 - t, 3);
            if (releasedScale.HasValue) transform.localScale = Vector3.Lerp(releaseScale, targetScale, eased);
            Position(Vector3.LerpUnclamped(start, target, eased)
                + Vector3.up * Mathf.Sin(t * Mathf.PI) * .22f);
            if (visual != null) visual.localRotation = Quaternion.Euler(0,
                Mathf.Sin(t * Mathf.PI) * 7, Mathf.Sin(t * Mathf.PI) * -5);
            if (gesture && visual != null) { visual.localScale = Vector3.one * (1 + (RefinedHand ? .6f : .2f) * (1 - eased));
                visual.localPosition = new Vector3(0, (RefinedHand ? .22f : .1f) * (1 - eased), -.06f * (1 - eased)); }
            if (!contacted && elapsed >= duration - .03f) {
                contacted = true; beforeContact?.Invoke();
            }
            elapsed += Time.unscaledDeltaTime; yield return null;
        }
        Position(target);
        transform.localScale = targetScale;
        if (!contacted) beforeContact?.Invoke();
        if (slam) { OnSlam.Invoke(); yield return new WaitForSecondsRealtime(.05f); impact?.Invoke(); }
        if (visual != null && (slam || duration <= .22f)) {
            visual.localRotation = Quaternion.identity;
            visual.localScale = Vector3.one; visual.localPosition = Vector3.zero;
            punch = visual.DOPunchScale(new Vector3(slam ? (RefinedHand && gesture ? .12f : .055f) : .025f,
                RefinedHand && gesture ? -.04f : -.025f, .025f), RefinedHand && gesture ? .15f : .12f, 1, .4f).SetUpdate(true);
            yield return punch.WaitForCompletion();
        }
        animating = false;
    }

    public void ReturnHome() {
        if (!Managed) return;
        CancelPose();
        returning = StartCoroutine(Return());
    }
    public void PublicArrival(Vector3 from) {
        CancelPose();
        if (!ReducedMotion) returning = StartCoroutine(ParkPublic(from));
    }
    private IEnumerator ParkPublic(Vector3 from) {
        animating = true;
        var start = transform.InverseTransformPoint(from);
        var elapsed = 0f;
        while (elapsed < .52f && visual != null) {
            var flight = Mathf.Clamp01((elapsed - .1f) / .22f);
            var lift = elapsed < .1f ? elapsed / .1f : 1 - Mathf.Clamp01((elapsed - .1f) / .42f);
            visual.localPosition = Vector3.Lerp(start, Vector3.zero, flight * flight * flight);
            visual.localScale = Vector3.one * (1 + .35f * lift);
            elapsed += Time.unscaledDeltaTime; yield return null;
        }
        if (visual != null) { visual.localPosition = Vector3.zero; visual.localScale = Vector3.one; }
        animating = false; returning = null;
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
        queuedSelection = slamSelection = false; SetRims(false, false);
        velocity = scaleVelocity = Vector3.zero; dragVelocity = Vector2.zero;
        externalDrag = 0;
        if (visual != null) { visual.DOKill(); visual.localPosition = Vector3.zero;
            visual.localRotation = Quaternion.identity; visual.localScale = Vector3.one; }
        if (face != null) face.sortingOrder = BaseSortingOrder;
    }
    void OnDisable() { CancelPose(); transform.DOKill(); }
    void OnDestroy() { CancelPose(); if (rimMaterial != null) Destroy(rimMaterial); }
}
