using UnityEngine;
using FlutterUnityIntegration;
using System;
using System.Runtime.InteropServices;
using System.Collections.Generic;
using DG.Tweening;
using System.Collections;
using UnityEngine.EventSystems;

public class UnityBridge : MonoBehaviour {
    public static UnityBridge Instance;
    
    // The prefab we generated in our AutoSceneBuilder
    private GameObject cardPrefab;

    // Keep track of spawned cards by ID to animate them later
    private Dictionary<string, GameObject> activeCards = new Dictionary<string, GameObject>();
    private Coroutine visualAction;
    private int visualGeneration;
    private bool managedVisuals;
    private bool refinedHand, reducedVisuals, hasHandSnapshot;
    private readonly HashSet<string> publicHand = new HashSet<string>();
    private readonly Dictionary<string, Vector3> pendingPublic = new Dictionary<string, Vector3>();
    private List<VisualAnchor> visualAnchors = new List<VisualAnchor>();
    private Tween cameraShake;
    private Tween collection;
    private Vector3 cameraHome;
    private ParticleSystem impactParticles;
    private readonly List<Coroutine> visualChildren = new List<Coroutine>();
    private readonly HashSet<string> seenVisuals = new HashSet<string>();
    private readonly HashSet<string> localHandIds = new HashSet<string>();
    private string submittedCard;
    public bool CanSubmitVisualIntent => managedVisuals && submittedCard == null;
    public bool SubmitVisualIntent(CardInstance card) {
        if (!CanSubmitVisualIntent || card == null || !localHandIds.Contains(card.cardId)) return false;
        submittedCard = card.cardId;
        NotifyFlutter("PLAY_CARD", card.cardId);
        return true;
    }

#if UNITY_WEBGL && !UNITY_EDITOR
    [DllImport("__Internal")]
    private static extern void PostToFlutter(string message);
#endif

    void Awake() {
        if (Instance == null) Instance = this;
        // Load the dummy prefab from resources
        cardPrefab = Resources.Load<GameObject>("CardPrefab");
    }

    void Start() {
#if UNITY_WEBGL && !UNITY_EDITOR
        // Flutter owns the transparent host's input, so the Unity canvas is
        // intentionally not focused. Losing CANVAS focus must not stop its
        // visual coroutines while the surrounding Flutter game keeps playing.
        // Browser tab throttling and Flutter's lifecycle resync still apply.
        Application.runInBackground = true;
        WebGLInput.captureAllKeyboardInput = false;
#endif
        // FORCE TRANSPARENCY AT RUNTIME (God Move)
        if (Camera.main != null) {
            Camera.main.clearFlags = CameraClearFlags.SolidColor;
            Camera.main.backgroundColor = new Color(0, 0, 0, 0);
            // Debug.Log("UnityBridge: Forced Camera transparency (Alpha 0)");
        }
        EnsurePointerInput();
        NotifyFlutter("UNITY_READY", "Unity initialized");
        NotifyFlutter("UNITY_VISUAL_READY", "1");
        NotifyFlutter("UNITY_CARD_FEEL_READY", "1");
        NotifyFlutter("UNITY_CARD_UI_READY", "1");
    }

    private void EnsurePointerInput() {
        // The saved scene predates the pointer setup in AutoSceneBuilder. Add
        // only missing input plumbing; never rebuild or replace its hierarchy.
        var events = FindFirstObjectByType<EventSystem>();
        if (events == null) {
            var input = new GameObject("HalabessaPointerInput");
            input.transform.SetParent(transform, false);
            input.AddComponent<EventSystem>();
            input.AddComponent<StandaloneInputModule>();
        }
        if (Camera.main != null && Camera.main.GetComponent<PhysicsRaycaster>() == null) {
            Camera.main.gameObject.AddComponent<PhysicsRaycaster>();
        }
    }

    void Update() {
#if UNITY_WEBGL && !UNITY_EDITOR
        if (WebGLInput.captureAllKeyboardInput) {
            WebGLInput.captureAllKeyboardInput = false;
        }
#endif
    }
    
    // Proxy for console visibility to avoid "object not found" routing issues
    public void ToggleConsole(string dummy) {
        UnityDebugConsole console = FindFirstObjectByType<UnityDebugConsole>(FindObjectsInactive.Include);
        if (console != null) {
            console.ToggleVisibility();
        }
        // Silently no-op if console component is absent (production build)
    }

    // Called from Flutter via _unityWidgetController.postMessage('UnityBridge', 'OnFlutterMessage', json)
    public void OnFlutterMessage(string messageJson) {
        // Silenced chatty log for production (God Move)
        try {
            MessageData data = JsonUtility.FromJson<MessageData>(messageJson);
            if (data == null) return;
            if (data.trace && (data.type == "VISUAL_ACTION" || data.type == "CANCEL_VISUALS"))
                Debug.Log($"Visual QA native {data.type} {data.kind} generation={data.generation} frame={Time.frameCount} focused={Application.isFocused} background={Application.runInBackground}");
            if (data.type == "CANCEL_VISUALS") {
                if (data.generation < visualGeneration) return;
                CancelVisuals(); visualGeneration = data.generation; seenVisuals.Clear(); return;
            }
            if (data.type == "VISUAL_ACTION") {
                if (data.protocol != 1 || data.generation < visualGeneration || string.IsNullOrEmpty(data.eventId)) return;
                if (data.generation > visualGeneration) seenVisuals.Clear();
                if (!seenVisuals.Add(data.eventId)) return;
                if (seenVisuals.Count > 256) { seenVisuals.Clear(); seenVisuals.Add(data.eventId); }
                var movingId = data.cards != null && data.cards.Count > 0
                    ? GetCardId(data.cards[data.cards.Count - 1]) : null;
                CancelVisuals(movingId, data.refinedHand);
                visualGeneration = data.generation; managedVisuals = true;
                refinedHand = data.refinedHand; reducedVisuals = data.reducedMotion;
                visualAnchors = data.anchors ?? visualAnchors;
                visualAction = StartCoroutine(PerformVisualAction(data)); return;
            }
            
            if (data.type == "HAND_SELECTION") {
                if (!managedVisuals || data.generation != visualGeneration || !localHandIds.Contains(data.cardId ?? "")) return;
                GameObject handCard;
                if (activeCards.TryGetValue(data.cardId, out handCard))
                    handCard.GetComponent<CardJuiceController>()?.SetHandSelection(data.queued, data.slam);
            } else if (data.type == "HAND_POSE") {
                if (!managedVisuals || data.generation != visualGeneration || !localHandIds.Contains(data.cardId ?? "")) return;
                GameObject handCard;
                if (activeCards.TryGetValue(data.cardId, out handCard))
                    handCard.GetComponent<CardJuiceController>()?.SetHandPose(data.peek, data.dragFraction, data.velocity);
            } else if (data.type == "SYNC_STATE") {
                managedVisuals = data.instant;
                refinedHand = data.refinedHand; reducedVisuals = data.reducedMotion;
                visualAnchors = data.anchors ?? visualAnchors;
                HandleSyncState(data.board, data.handCards, data.instant, data.publicHandIds, true);
                ApplyHandSelections(data.handSelections);
                ApplyHandPoses(data.handPoses);
                foreach (var card in activeCards.Values) {
                    var juice = card.GetComponent<CardJuiceController>();
                    if (juice != null) juice.ReducedMotion = data.reducedMotion;
                }
            } else if (data.type == "INVALID_MOVE") {
                if (!managedVisuals || data.generation != visualGeneration || string.IsNullOrEmpty(data.cardId)) return;
                GameObject rejected;
                if (activeCards.TryGetValue(data.cardId, out rejected)) {
                    if (submittedCard == data.cardId) submittedCard = null;
                    var juice = rejected.GetComponent<CardJuiceController>();
                    if (juice != null) { juice.ReducedMotion = data.reducedMotion; juice.ReturnHome(); }
                }
            } else if (data.type == "START_TIMER") {
                if (TurnTimer.Instance != null) {
                    TurnTimer.Instance.StartTimer(data.duration);
                }
            } else if (data.type == "SET_MODE") {
                GameStateManager.Instance.SetMode(data.mode);
            } else if (data.type == "UPDATE_SKINS") {
                DeckManager.Instance?.UpdateSkins(data.skinId);
            }
        } catch (Exception e) {
            Debug.LogError("Error parsing Flutter message: " + e.Message);
        }
    }

    private void ApplyHandSelections(List<HandSelection> selections) {
        foreach (var id in localHandIds) {
            GameObject card;
            if (!activeCards.TryGetValue(id, out card)) continue;
            var pose = selections?.Find(item => item.cardId == id);
            card.GetComponent<CardJuiceController>()?.SetHandSelection(pose != null && pose.queued, pose != null && pose.slam);
        }
    }
    private void ApplyHandPoses(List<HandPose> poses) {
        if (!refinedHand || poses == null) return;
        foreach (var pose in poses) {
            GameObject card;
            if (localHandIds.Contains(pose.cardId ?? "") && activeCards.TryGetValue(pose.cardId, out card))
                card.GetComponent<CardJuiceController>()?.SetHandPose(pose.peek, pose.dragFraction, pose.velocity);
        }
    }

    private void HandleSyncState(List<CardJson> boardCards, List<CardJson> handCards, bool instant = false,
        List<string> publicIds = null, bool animatePublic = false) {
        boardCards = boardCards ?? new List<CardJson>(); handCards = handCards ?? new List<CardJson>();
        localHandIds.Clear();
        foreach (var card in handCards) localHandIds.Add(GetCardId(card));
        if (submittedCard != null && !localHandIds.Contains(submittedCard)) submittedCard = null;
        if (cardPrefab == null) {
            Debug.LogError("CardPrefab is missing from Resources folder! Cannot spawn cards.");
            return;
        }

        // 1. Identify all desired cards and their target positions
        HashSet<string> desiredIds = new HashSet<string>();
        Dictionary<string, Vector3> targetPositions = new Dictionary<string, Vector3>();
        Dictionary<string, bool> isOnHand = new Dictionary<string, bool>();

        // Prep Board Positions
        float boardStartX = -1.5f;
        float boardSpacing = 1.0f;
        for (int i = 0; i < boardCards.Count; i++) {
            string id = GetCardId(boardCards[i]);
            desiredIds.Add(id);
            targetPositions[id] = managedVisuals
                ? Anchor("board", new Vector3(0, .1f, -1)) +
                    new Vector3(boardCards.Count <= 4 ? (i - (boardCards.Count - 1) / 2f) * 1.12f : i * .006f, i * .001f, 0)
                : new Vector3(boardStartX + i * boardSpacing, .1f, -1);
            isOnHand[id] = false;
        }

        // Prep Hand Positions
        float handBaseZ = -2.5f;
        float handY = -1.5f;
        float handSpacing = 0.6f;
        float handStartX = -((handCards.Count - 1) * handSpacing) / 2f;
        for (int i = 0; i < handCards.Count; i++) {
            string id = GetCardId(handCards[i]);
            desiredIds.Add(id);
            var x = handStartX + (i * handSpacing);
            targetPositions[id] = managedVisuals
                ? Anchor("hand", new Vector3(0, handY, handBaseZ)) + new Vector3(x, 0, -.07f * x * x)
                : new Vector3(x, handY, handBaseZ);
            isOnHand[id] = true;
        }

        // 2. Cleanup: Remove cards no longer in the state
        List<string> keysToRemove = new List<string>();
        foreach (var kvp in activeCards) {
            if (!desiredIds.Contains(kvp.Key)) {
                if (kvp.Value != null) {
                    kvp.Value.transform.DOKill();
                    Destroy(kvp.Value);
                }
                keysToRemove.Add(kvp.Key);
            }
        }
        foreach (var k in keysToRemove) activeCards.Remove(k);

        // 3. Update Existing and Spawn New
        foreach (var id in desiredIds) {
            Vector3 targetPos = targetPositions[id];
            bool inHand = isOnHand[id];
            var roll = managedVisuals && inHand
                ? -(handCards.FindIndex(c => GetCardId(c) == id) - (handCards.Count - 1) / 2f) * 2.005352f : 0;
            if (managedVisuals && !inHand && boardCards.Count <= 4) {
                var boardIndex = boardCards.FindIndex(c => GetCardId(c) == id);
                var radians = new float[] { -.12f, -.02f, .12f, .02f };
                roll = -(boardCards.Count < 4
                    ? (boardIndex - (boardCards.Count - 1) / 2f) * .08f
                    : radians[Mathf.Clamp(boardIndex, 0, 3)]) * Mathf.Rad2Deg;
            }

            var existed = activeCards.ContainsKey(id);
            var from = existed ? (activeCards[id].GetComponent<CardJuiceController>()?.RenderedCenter ?? activeCards[id].transform.position) : targetPos;
            if (refinedHand && inHand && existed && hasHandSnapshot && animatePublic &&
                publicIds != null && publicIds.Contains(id) && !publicHand.Contains(id))
                pendingPublic[id] = from;
            if (refinedHand && inHand && publicIds != null && publicIds.Contains(id)) roll = 0;
            if (!activeCards.ContainsKey(id)) {
                // Spawn new
                GameObject newCard = Instantiate(cardPrefab);
                newCard.name = (inHand ? "Hand_" : "Board_") + id;
                newCard.transform.localScale = Vector3.one * 1.5f;
                
                // Initial position (coming from above)
                newCard.transform.position = new Vector3(targetPos.x, targetPos.y + 5f, targetPos.z + 5f);
                newCard.transform.localRotation = Quaternion.Euler(inHand ? 60 : 90, 0, roll);

                Debug.Log($"[PRODUCTION_FIX] Spawned card: {id} at {newCard.transform.position}");

                CardInstance cardScript = newCard.GetComponent<CardInstance>();
                if (cardScript != null) {
                    cardScript.cardId = id;
                    // Find card data for metadata
                    CardJson meta = boardCards.Find(c => GetCardId(c) == id) ?? handCards.Find(c => GetCardId(c) == id);
                    if (meta != null) {
                        cardScript.rank = meta.rank;
                        cardScript.suit = meta.suit;
                    }
                    // Without this every card spawns as an untextured white
                    // quad -- the prefab's MeshRenderer never gets a
                    // material.mainTexture assigned anywhere else.
                    DeckManager.CardSkin skin = DeckManager.Instance != null ? DeckManager.Instance.GetSkinForCard(id) : null;
                    if (skin != null) cardScript.ApplySkin(skin);
                    Debug.Log($"[PRODUCTION_FIX] Animating card {id} flying to {targetPos}");
                    if (instant) cardScript.SetPresentationPosition(targetPos);
                    else cardScript.PlayAnimation(targetPos, 0.6f);
                } else {
                    newCard.transform.position = targetPos;
                }
                activeCards.Add(id, newCard);
            } else {
                // Update existing
                GameObject existing = activeCards[id];
                existing.transform.DOKill();
                if (instant) {
                    existing.transform.SetPositionAndRotation(targetPos, Quaternion.Euler(inHand ? 60 : 90, 0, roll));
                    existing.GetComponent<CardInstance>()?.SetPresentationPosition(targetPos);
                    existing.transform.localScale = Vector3.one * 1.5f;
                }
                else {
                    existing.transform.DOMove(targetPos, 0.4f).SetEase(Ease.OutQuad)
                        .OnUpdate(() => { if (existing != null) existing.GetComponent<CardInstance>()?.SetPresentationPosition(existing.transform.position); });
                    existing.transform.DORotate(new Vector3(inHand ? 60 : 90, 0, 0), 0.4f);
                }
            }
            var juice = activeCards[id].GetComponent<CardJuiceController>();
            if (juice == null && managedVisuals) juice = activeCards[id].AddComponent<CardJuiceController>();
            // Optional logical-size anchors keep card art and its collider at
            // the same readable size as the Flutter hand in either orientation.
            if (managedVisuals && instant && Camera.main != null) {
                var index = inHand ? handCards.FindIndex(c => GetCardId(c) == id)
                    : boardCards.FindIndex(c => GetCardId(c) == id);
                var sized = visualAnchors.Find(a => a.name == (inHand ? "hand" : "board"));
                if (sized != null && sized.width > 0 && sized.height > 0) {
                    var pose = visualAnchors.Find(a => a.name == "hand" + index);
                    var x = inHand && pose != null ? pose.x : sized.x;
                    var y = inHand && pose != null ? pose.y : sized.y;
                    if (!inHand) {
                        // Expose the top face and readable previous ranks rather
                        // than collapsing every accepted card into .006 units.
                        if (boardCards.Count <= 4) {
                            // Same physical pile poses as Flutter's boardCardOffset.
                            // These are presentation positions, never move rules.
                            var poses = new Vector2[] { new Vector2(-.48f, .13f),
                                new Vector2(0, -.36f), new Vector2(.46f, .05f),
                                new Vector2(.12f, .54f) };
                            var poseOffset = boardCards.Count < 4
                                ? new Vector2((index - (boardCards.Count - 1) / 2f) * .45f, 0)
                                : poses[Mathf.Clamp(index, 0, 3)];
                            x += poseOffset.x * sized.width;
                            y += poseOffset.y * sized.width;
                        } else {
                            x += (((index * 13) % 21) - 10) * sized.width * .018f;
                            y += (((index * 11) % 15) - 7) * sized.height * .01f;
                        }
                    }
                    targetPos = ViewportPosition(x, y, targetPos);
                    var rotation = Camera.main.transform.rotation * Quaternion.Euler(0, 0, roll);
                    var depth = Camera.main.WorldToViewportPoint(targetPos).z;
                    var bottom = Camera.main.ViewportToWorldPoint(new Vector3(x, 1 - y - sized.height / 2, depth));
                    var top = Camera.main.ViewportToWorldPoint(new Vector3(x, 1 - y + sized.height / 2, depth));
                    var scale = Vector3.Distance(bottom, top); // imported mesh is one unit high
                    var root = activeCards[id].transform;
                    root.SetPositionAndRotation(targetPos, rotation);
                    root.localScale = Vector3.one * scale;
                    activeCards[id].GetComponent<CardInstance>()?.SetPresentationPosition(targetPos);
                }
            }
            if (juice != null) {
                juice.Managed = managedVisuals;
                juice.RefinedHand = refinedHand;
                juice.ReducedMotion = reducedVisuals;
                juice.BaseSortingOrder = inHand ? 60 + handCards.FindIndex(c => GetCardId(c) == id)
                    : boardCards.FindIndex(c => GetCardId(c) == id);
                juice.ConfigureInput(inHand);
                if (inHand) juice.RememberHome(targetPos, activeCards[id].transform.rotation);
                Vector3 publicFrom;
                if (refinedHand && inHand && pendingPublic.TryGetValue(id, out publicFrom) &&
                    Vector3.Distance(publicFrom, targetPos) > .005f) {
                    pendingPublic.Remove(id); juice.PublicArrival(publicFrom);
                }
            }
        }
        publicHand.Clear();
        if (publicIds != null) foreach (var id in publicIds) publicHand.Add(id);
        foreach (var id in new List<string>(pendingPublic.Keys))
            if (!localHandIds.Contains(id) || !publicHand.Contains(id)) pendingPublic.Remove(id);
        hasHandSnapshot = true;
    }

    private Vector3 Anchor(string name, Vector3 fallback) {
        var a = visualAnchors.Find(item => item.name == name);
        if (!managedVisuals || a == null || Camera.main == null) return fallback;
        return ViewportPosition(a.x, a.y, fallback);
    }
    private Vector3 ViewportPosition(float x, float y, Vector3 fallback) {
        var ray = Camera.main.ViewportPointToRay(new Vector3(x, 1 - y, 0));
        float distance;
        return new Plane(Vector3.up, new Vector3(0, .1f, 0)).Raycast(ray, out distance)
            ? ray.GetPoint(distance) : fallback;
    }

    public bool IsTableDrop(Vector3 worldPosition) {
        // This classifies a visual drop area, not move legality. Flutter still
        // validates the same PLAY_CARD intent. Legacy exports keep their region.
        var board = visualAnchors.Find(item => item.name == "board");
        var hand = visualAnchors.Find(item => item.name == "hand");
        if (!managedVisuals || board == null || hand == null || Camera.main == null) {
            return worldPosition.z > -1.5f;
        }
        var point = Camera.main.WorldToViewportPoint(worldPosition);
        var lowerEdge = 1 - (board.y + hand.y) * .5f;
        return point.z > 0 && point.x >= 0 && point.x <= 1 &&
            point.y >= lowerEdge && point.y <= 1;
    }

    private IEnumerator PerformVisualAction(MessageData data) {
        var generation = visualGeneration;
        var started = Time.realtimeSinceStartup;
        var capture = data.kind == "CardsCollected" || data.kind == "CardSlammed";
        // Gesture delivery is independent of capture rules and legacy CardSlammed.
        var gesture = data.deliveryStyle == "slam";
        var oldPositions = new Dictionary<string, Vector3>();
        var oldScales = new Dictionary<string, Vector3>();
        foreach (var entry in activeCards) if (entry.Value != null) oldPositions[entry.Key] = entry.Value.transform.position;
        foreach (var entry in activeCards) if (entry.Value != null) oldScales[entry.Key] = entry.Value.transform.localScale;
        var displayedBoard = capture && data.cards != null ? data.cards : data.board;
        HandleSyncState(displayedBoard, data.handCards, true, data.publicHandIds);
        ApplyHandSelections(data.handSelections); ApplyHandPoses(data.handPoses);
        foreach (var card in activeCards.Values) {
            var juice = card.GetComponent<CardJuiceController>();
            if (juice != null) juice.ReducedMotion = data.reducedMotion;
        }
        Action contact = () => {
            if (generation != visualGeneration) return;
            SendVisualSignal("VISUAL_CONTACT", data);
        };
        if (data.kind == "CardPlayed" || capture) {
            var cards = data.cards ?? new List<CardJson>();
            if (cards.Count > 0) {
                var id = GetCardId(cards[cards.Count - 1]);
                GameObject card;
                if (activeCards.TryGetValue(id, out card)) {
                    var target = card.transform.position;
                    Vector3 previous;
                    card.GetComponent<CardInstance>()?.SetPresentationPosition(oldPositions.TryGetValue(id, out previous) ? previous
                        : Anchor("seat" + data.actor, target + Vector3.up * 2));
                    var juice = card.GetComponent<CardJuiceController>();
                    Vector3 releaseScale;
                    if (juice != null) yield return juice.Fly(target, data.reducedMotion ? 0 : gesture ? (refinedHand ? .16f : .2f) : .22f, capture || gesture, contact,
                        () => Impact(target, capture ? data.team == data.ownTeam : data.actor == 0 || data.actor == 2), gesture,
                        refinedHand && oldScales.TryGetValue(id, out releaseScale) ? (Vector3?)releaseScale : null);
                    else { card.transform.position = target; contact(); }
                }
            }
        } else if (data.kind == "CardDrawn" && !data.reducedMotion) {
            var hand = data.handCards ?? new List<CardJson>();
            // Independent cards stagger inside this one visual action.
            for (var i = 0; i < hand.Count; i++) {
                var id = GetCardId(hand[i]); GameObject card;
                if (!activeCards.TryGetValue(id, out card) || oldPositions.ContainsKey(id)) continue;
                var target = card.transform.position;
                card.GetComponent<CardInstance>()?.SetPresentationPosition(Anchor("deck", Anchor("seat2", target + Vector3.up * 2)));
                var juice = card.GetComponent<CardJuiceController>();
                if (juice != null) visualChildren.Add(StartCoroutine(juice.Fly(target, .38f, false, null)));
                yield return new WaitForSecondsRealtime(.07f);
            }
        } else if (data.kind == "RoundWon" && !data.reducedMotion) {
            CelebrationManager.Instance?.PlayWinEffect();
        }
        if (data.kind == "CardsCollected" && !data.reducedMotion) {
            var remaining = 1f - (Time.realtimeSinceStartup - started);
            if (remaining > 0) yield return new WaitForSecondsRealtime(remaining);
            var destination = Anchor(data.team == data.ownTeam ? "ourPile" : "rivalPile", new Vector3(-2, .1f, -2));
            var collect = DOTween.Sequence().SetUpdate(true);
            collection = collect;
            foreach (var card in activeCards.Values) {
                if (displayedBoard == null || !displayedBoard.Exists(c => GetCardId(c) == card.GetComponent<CardInstance>()?.cardId)) continue;
                collect.Join(card.transform.DOMove(destination, .4f).SetEase(Ease.InOutCubic)
                    .OnUpdate(() => { if (card != null) card.GetComponent<CardInstance>()?.SetPresentationPosition(card.transform.position); }));
                collect.Join(card.transform.DOScale(.25f, .4f).SetEase(Ease.InCubic));
            }
            yield return collect.WaitForCompletion();
            collection = null;
        } else if (!data.reducedMotion) {
            var remaining = data.durationMs / 1000f - (Time.realtimeSinceStartup - started);
            if (remaining > 0) yield return new WaitForSecondsRealtime(remaining);
        }
        if (generation != visualGeneration) yield break;
        HandleSyncState(data.board, data.handCards, true);
        ApplyHandSelections(data.handSelections);
        visualAction = null;
        SendVisualSignal("VISUAL_ACTION_COMPLETE", data);
    }

    private void Impact(Vector3 position, bool ours) {
        if (Camera.main != null) {
            cameraShake?.Kill(); cameraHome = Camera.main.transform.position;
            cameraShake = Camera.main.transform.DOShakePosition(.12f, .025f, 8, 60).SetUpdate(true)
                .OnComplete(() => { if (Camera.main != null) Camera.main.transform.position = cameraHome; cameraShake = null; });
        }
        if (impactParticles == null) {
            var shader = Shader.Find("Sprites/Default");
            if (shader == null) return;
            var go = new GameObject("CardImpactParticles"); go.transform.SetParent(transform, false);
            impactParticles = go.AddComponent<ParticleSystem>(); impactParticles.Stop();
            var main = impactParticles.main; main.loop = false; main.playOnAwake = false;
            main.maxParticles = 16; main.startLifetime = .25f; main.startSpeed = .4f;
            main.startSize = .035f; main.useUnscaledTime = true;
            var emission = impactParticles.emission; emission.enabled = false;
            var shape = impactParticles.shape; shape.enabled = false;
            go.GetComponent<ParticleSystemRenderer>().material = new Material(shader);
        }
        impactParticles.transform.position = position;
        var settings = impactParticles.main;
        settings.startColor = ours ? new Color(.47f, .82f, .69f) : new Color(.93f, .46f, .48f);
        impactParticles.Play();
        impactParticles.Emit(12);
    }

    private void CancelVisuals(string movingCardId = null, bool preserveHand = false) {
        if (!preserveHand) { pendingPublic.Clear(); publicHand.Clear(); hasHandSnapshot = false; }
        submittedCard = null;
        if (visualAction != null) StopCoroutine(visualAction);
        visualAction = null;
        collection?.Kill(); collection = null;
        foreach (var child in visualChildren) if (child != null) StopCoroutine(child);
        visualChildren.Clear();
        foreach (var entry in activeCards) if (entry.Value != null) {
            var card = entry.Value;
            if (preserveHand && localHandIds.Contains(entry.Key) && entry.Key != movingCardId) continue;
            card.transform.DOKill();
            var juice = card.GetComponent<CardJuiceController>();
            if (preserveHand && entry.Key == movingCardId) juice?.PreserveReleasePose();
            else juice?.CancelPose();
        }
        if (cameraShake != null) { cameraShake.Kill(); cameraShake = null;
            if (Camera.main != null) Camera.main.transform.position = cameraHome; }
        impactParticles?.Stop(true, ParticleSystemStopBehavior.StopEmittingAndClear);
    }
    void OnDisable() { CancelVisuals(); }
    void OnDestroy() {
        CancelVisuals();
        if (impactParticles != null) {
            var renderer = impactParticles.GetComponent<ParticleSystemRenderer>();
            if (renderer != null) Destroy(renderer.sharedMaterial);
        }
    }
    private void SendVisualSignal(string name, MessageData data) {
        if (data.trace)
            Debug.Log($"Visual QA native {name} generation={data.generation} frame={Time.frameCount}");
        SendToFlutter(JsonUtility.ToJson(new VisualSignal { @event = name,
            eventId = data.eventId, generation = data.generation }));
    }

    private string GetCardId(CardJson c) {
        if (!string.IsNullOrEmpty(c.id)) return c.id;
        return (c.suit ?? "nil") + "_" + (c.rank ?? "nil");
    }

    public void NotifyFlutter(string eventName, string data = "") {
        SendToFlutter(JsonUtility.ToJson(new StringSignal { @event = eventName, data = data }));
    }
    private void SendToFlutter(string message) {
#if UNITY_WEBGL && !UNITY_EDITOR
        PostToFlutter(message);
#else
        UnityMessageManager.Instance.SendMessageToFlutter(message);
#endif
    }

    [Serializable]
    public class MessageData {
        public int protocol, generation, durationMs, contactLeadMs, pauseMs, shakeMs, actor;
        public string eventId, kind, team, ownTeam, deliveryStyle;
        public bool instant, reducedMotion, peek, queued, slam, trace, refinedHand;
        public float dragFraction, velocity;
        public List<CardJson> cards;
        public List<VisualAnchor> anchors;
        public List<HandSelection> handSelections;
        public List<HandPose> handPoses;
        public List<string> publicHandIds;
        public string type;
        public string cardId;
        public float x;
        public float y;
        public string skinId;
        public List<CardJson> board;
        public List<CardJson> handCards;
        public float duration;
        public string mode;
    }
    [Serializable] public class VisualAnchor { public string name; public float x, y, width, height; }
    [Serializable] public class HandSelection { public string cardId; public bool queued, slam; }
    [Serializable] public class HandPose { public string cardId; public bool peek; public float dragFraction, velocity; }
    [Serializable] private class StringSignal { public string @event, data; }
    [Serializable] private class VisualSignal { public string @event, eventId; public int generation; }

    [Serializable]
    public class CardJson {
        public string id;
        public string rank;
        public string suit;
    }
}
