using System;
using System.Collections.Generic;
using System.Reflection;
using System.Threading.Tasks;
using UnityEngine;
using UnityEngine.EventSystems;

// Explicit, in-memory Editor checks. Outside Assets: not imported into a player.
public static class CardJuiceSmoke {
    // Run between CLI requests with background ticks enabled for this QA session.
    public static object Start() {
        if (!Application.isPlaying) throw new Exception("Enter isolated Play Mode first.");
        var background = Application.runInBackground;
        Application.runInBackground = true; // This QA session only, not PlayerSettings.
        var path = System.IO.Path.GetFullPath(System.IO.Path.Combine(Application.dataPath,
            "../../../build/unity-card-art-deferred-smoke.json"));
        System.IO.File.WriteAllText(path, "{\"running\":true}");
        _ = Report(path, background);
        return new { started = true, report = "build/unity-card-art-deferred-smoke.json" };
    }
    private static async Task Report(string path, bool background) {
        object verdict;
        try { verdict = new { success = true, result = await Run() }; }
        catch (Exception error) { verdict = new { success = false, error = error.ToString() }; }
        finally { Application.runInBackground = background; }
        System.IO.File.WriteAllText(path, Newtonsoft.Json.JsonConvert.SerializeObject(verdict,
            Newtonsoft.Json.Formatting.Indented));
    }
    static object Field(object owner, string name) => owner.GetType()
        .GetField(name, BindingFlags.Instance | BindingFlags.NonPublic)?.GetValue(owner);
    static Dictionary<string, GameObject> Cards(UnityBridge bridge) =>
        (Dictionary<string, GameObject>)Field(bridge, "activeCards");
    static void Check(bool passed, string name, List<string> results) {
        if (!passed) throw new Exception("Presentation check failed: " + name);
        results.Add(name);
    }
    static UnityBridge.CardJson Card(string suit, string rank) =>
        new UnityBridge.CardJson { suit = suit, rank = rank };
    static List<UnityBridge.CardJson> Hand() => new List<UnityBridge.CardJson> {
        Card("clubs", "six"), Card("diamonds", "nine"), Card("clubs", "ace"), Card("spades", "eight") };
    static List<UnityBridge.CardJson> Table() => new List<UnityBridge.CardJson> {
        Card("diamonds", "two"), Card("hearts", "six") };
    static List<UnityBridge.VisualAnchor> Anchors() => new List<UnityBridge.VisualAnchor> {
        new UnityBridge.VisualAnchor { name = "hand", x = .65f, y = .84f },
        new UnityBridge.VisualAnchor { name = "board", x = .46f, y = .605f },
        new UnityBridge.VisualAnchor { name = "deck", x = .3f, y = .2f },
        new UnityBridge.VisualAnchor { name = "ourPile", x = .075f, y = .88f },
        new UnityBridge.VisualAnchor { name = "rivalPile", x = .92f, y = .45f },
        new UnityBridge.VisualAnchor { name = "seat0", x = .06f, y = .12f } };
    static void Send(UnityBridge bridge, UnityBridge.MessageData message) => bridge.OnFlutterMessage(JsonUtility.ToJson(message));
    static UnityBridge.MessageData Snapshot(List<UnityBridge.CardJson> board, List<UnityBridge.CardJson> hand) =>
        new UnityBridge.MessageData { type = "SYNC_STATE", instant = true,
            board = board, handCards = hand, anchors = Anchors() };
    static UnityBridge.MessageData Capture(int generation, bool reduced = false) {
        var remaining = Hand(); remaining.RemoveAt(0);
        var captured = Table(); captured.Add(Card("clubs", "six"));
        return new UnityBridge.MessageData { type = "VISUAL_ACTION", protocol = 1,
            generation = generation, eventId = "isolated-visual-qa:" + generation,
            kind = "CardsCollected", cards = captured, board = new List<UnityBridge.CardJson>(),
            handCards = remaining, team = "teamA", ownTeam = "teamA", actor = 0,
            durationMs = reduced ? 0 : 1400, reducedMotion = reduced, anchors = Anchors() };
    }

    public static object Inspect() {
        var camera = UnityEngine.Object.FindFirstObjectByType<Camera>();
        var prefab = Resources.Load<GameObject>("CardPrefab");
        var celebration = UnityEngine.Object.FindFirstObjectByType<CelebrationManager>();
        return new {
            scene = UnityEngine.SceneManagement.SceneManager.GetActiveScene().path,
            playing = Application.isPlaying,
            eventSystems = UnityEngine.Object.FindObjectsByType<EventSystem>(FindObjectsSortMode.None).Length,
            physicsRaycaster = camera != null && camera.GetComponent<PhysicsRaycaster>() != null,
            prefabPresent = prefab != null,
            cardInstance = prefab != null && prefab.GetComponent<CardInstance>() != null,
            collider = prefab != null && prefab.GetComponent<Collider>() != null,
            winParticlesAssigned = celebration != null && (Field(celebration, "winConfetti") as ParticleSystem) != null,
            captureParticlesAssigned = celebration != null && (Field(celebration, "basraSparkles") as ParticleSystem) != null
        };
    }

    public static object InspectDrops() {
        var bridge = UnityBridge.Instance;
        if (!Application.isPlaying || bridge == null) throw new Exception("Use the isolated Play Mode session.");
        try {
            Send(bridge, Snapshot(Table(), Hand()));
            var board = Cards(bridge)["hearts_six"].transform.position;
            var hand = Cards(bridge)["clubs_six"].transform.position;
            return new { tableWorldZ = board.z, handWorldZ = hand.z,
                oldTableDropAccepted = board.z > -1.5f, oldHandDropAccepted = hand.z > -1.5f,
                tableScreen = Camera.main.WorldToViewportPoint(board).ToString(),
                handScreen = Camera.main.WorldToViewportPoint(hand).ToString() };
        } finally {
            Send(bridge, Snapshot(new List<UnityBridge.CardJson>(), new List<UnityBridge.CardJson>()));
        }
    }

    public static async Task<object> Run() {
        if (!Application.isPlaying) throw new Exception("Run this check in the isolated Editor Play Mode session.");
        var bridge = UnityBridge.Instance;
        if (bridge == null) throw new Exception("Existing UnityBridge not loaded.");
        var results = new List<string>();
        var tweenWarnings = new List<string>();
        var runtimeErrors = new List<string>();
        Application.LogCallback trackWarnings = (message, trace, type) => {
            if (type == LogType.Exception || type == LogType.Error || type == LogType.Assert) runtimeErrors.Add(message);
            if (message.Contains("DOTWEEN") && (message.Contains("missing/null") || message.Contains("destroyed"))) {
                tweenWarnings.Add(message);
            }
        };
        Application.logMessageReceived += trackWarnings;
        var domain = GameStateManager.Instance;
        var originalDomainState = domain.currentState;
        var camera = Camera.main;
        var cameraHome = camera.transform.position;
        var events = EventSystem.current;
        var eventsEnabled = events != null && events.enabled;
        var generation = Mathf.Max(100, (int)Field(bridge, "visualGeneration") + 1);
        try {
            Send(bridge, new UnityBridge.MessageData { type = "CANCEL_VISUALS", generation = generation });
            Send(bridge, Snapshot(Table(), Hand()));
            await Task.Delay(60);
            var cards = Cards(bridge);
            Check(Mathf.Abs(cards["hearts_six"].transform.position.x -
                cards["diamonds_two"].transform.position.x) > 1.05f,
                "small table group exposes full card faces", results);
            Check(cards.Count == 6, "public board plus local hand only", results);
            Check(bridge.IsTableDrop(cards["hearts_six"].transform.position),
                "landscape visual table accepts drop", results);
            Check(!bridge.IsTableDrop(cards["clubs_six"].transform.position),
                "hand region does not submit drop", results);
            var portrait = Snapshot(Table(), Hand());
            portrait.anchors[0].y = .88f; portrait.anchors[1].y = .5f;
            Send(bridge, portrait);
            Check(bridge.IsTableDrop(Cards(bridge)["hearts_six"].transform.position) &&
                !bridge.IsTableDrop(Cards(bridge)["clubs_six"].transform.position),
                "portrait table and hand regions remain separate", results);
            Send(bridge, Snapshot(Table(), Hand()));
            Check(UnityEngine.Object.FindObjectsByType<EventSystem>(FindObjectsSortMode.None).Length == 1,
                "one pointer EventSystem", results);
            Check(camera.GetComponent<PhysicsRaycaster>() != null, "camera physics raycaster", results);
            // Direct callback fixtures must not compete with the desktop cursor.
            // This is test isolation only; restore real pointer processing below.
            if (events != null) events.enabled = false;
            var card = cards["clubs_six"];
            var juice = card.GetComponent<CardJuiceController>();
            var rootScale = card.transform.localScale;
            var home = card.transform.position;
            Check(juice != null && juice.Managed, "managed child controller exists", results);
            Check(!card.GetComponent<Studio.OverOne.DragMe.Components.DragMe>().enabled,
                "managed hand has one pointer owner", results);
            var pointer = new PointerEventData(events) { pointerId = -1,
                position = camera.WorldToScreenPoint(home) };
            var tableJuice = cards["hearts_six"].GetComponent<CardJuiceController>();
            tableJuice.OnPointerDown(pointer); tableJuice.OnPointerClick(pointer);
            Check(Field(bridge, "submittedCard") == null, "public table cannot submit a hand play", results);
            juice.OnPointerDown(pointer); juice.OnPointerUp(pointer); juice.OnPointerClick(pointer);
            Check((string)Field(bridge, "submittedCard") == "clubs_six", "tap forwards the original card intent", results);
            Check(!bridge.SubmitVisualIntent(cards["clubs_ace"].GetComponent<CardInstance>()),
                "pending request blocks a second hand command", results);
            Send(bridge, new UnityBridge.MessageData { type = "INVALID_MOVE", generation = generation, cardId = "clubs_six" });
            await Task.Delay(350);
            Check(Field(bridge, "submittedCard") == null, "rejection unlocks local input", results);
            pointer.position = camera.WorldToScreenPoint(home);
            juice.OnPointerDown(pointer); juice.OnBeginDrag(pointer);
            pointer.position = camera.WorldToScreenPoint(cards["hearts_six"].transform.position);
            pointer.delta = new Vector2(0, 100);
            juice.OnDrag(pointer);
            Check(Vector3.Distance(card.transform.position, home) > .1f,
                "pointer drag moves the root and collider", results);
            juice.OnPointerUp(pointer); juice.OnEndDrag(pointer);
            Check((string)Field(bridge, "submittedCard") == "clubs_six", "table drop forwards one validated intent", results);
            juice.OnPointerClick(pointer);
            Check(!bridge.SubmitVisualIntent(card.GetComponent<CardInstance>()), "release plus click cannot duplicate play", results);
            Send(bridge, new UnityBridge.MessageData { type = "INVALID_MOVE", generation = generation, cardId = "clubs_six" });
            await Task.Delay(350);
            Check(Vector3.Distance(card.transform.position, home) < .005f, "rejected dragged card springs home", results);
            pointer.position = camera.WorldToScreenPoint(home);
            juice.OnPointerDown(pointer); juice.OnBeginDrag(pointer);
            pointer.position += new Vector2(10, 0); juice.OnDrag(pointer);
            juice.OnPointerUp(pointer); juice.OnEndDrag(pointer);
            await Task.Delay(350);
            Check(Field(bridge, "submittedCard") == null && Vector3.Distance(card.transform.position, home) < .005f,
                "invalid visual drop returns without a command", results);
            Check(card.GetComponent<Studio.OverOne.DragMe.Components.DragMe>().Config != null,
                "drag configuration assigned before Awake", results);
            Check(!card.GetComponent<MeshRenderer>().enabled && card.transform.Find("CardVisual") != null,
                "child artwork separates root collider", results);
            var face = card.transform.Find("CardVisual").GetComponent<MeshRenderer>();
            var mesh = card.GetComponent<MeshFilter>().sharedMesh;
            Check(face.sharedMaterial.mainTexture != null && face.sharedMaterial.mainTexture.name == "clubs_six",
                "actual rank-specific Flutter face bound", results);
            Check(Mathf.Abs(mesh.bounds.size.x / mesh.bounds.size.y - .7f) < .001f,
                "card artwork retains 70:100 proportions", results);
            Check(Vector3.Dot(card.transform.TransformDirection(mesh.normals[0]), camera.transform.position - home) > 0,
                "hand front faces camera", results);
            Physics.SyncTransforms();
            RaycastHit hit;
            Check(card.GetComponent<Collider>().Raycast(new Ray(camera.transform.position,
                (home - camera.transform.position).normalized), out hit, 100),
                "front-side collider accepts pointer ray", results);
            Send(bridge, new UnityBridge.MessageData { type = "UPDATE_SKINS", skinId = "neon_card" });
            Check(face.sharedMaterial.mainTexture == DeckManager.Instance.GetSkinForCard("clubs_six").frontTexture,
                "skin change updates child artwork", results);
            Send(bridge, new UnityBridge.MessageData { type = "UPDATE_SKINS", skinId = "default_card" });
            var deck = DeckManager.Instance;
            var custom = new DeckManager.CardSkin { skinId = "isolated_custom_qa",
                frontTexture = face.sharedMaterial.mainTexture as Texture2D,
                backTexture = Resources.Load<Texture2D>("HalabessaCards/default_card/back") };
            var configuredSkins = (Dictionary<string, DeckManager.CardSkin>)Field(deck, "skinDict");
            deck.availableSkins.Add(custom); configuredSkins.Add(custom.skinId, custom);
            try {
                deck.UpdateSkins("neon_card");
                Check(deck.GetSkinForCard("clubs_six").skinId == "neon_card",
                    "explicit built-in selection wins over custom fallback", results);
                deck.UpdateSkins(custom.skinId);
                Check(ReferenceEquals(deck.GetSkinForCard("clubs_six"), custom),
                    "exact configured custom skin remains supported", results);
            } finally {
                configuredSkins.Remove(custom.skinId); deck.availableSkins.Remove(custom);
                deck.UpdateSkins("default_card");
            }
            card.GetComponent<CardInstance>().SetFaceUp(false);
            Check(face.sharedMaterial.mainTexture.name == "back", "face-down shows only card back", results);
            card.GetComponent<CardInstance>().SetFaceUp(true);
            var peekFrame = Time.frameCount;
            juice.OnPointerDown(null);
            await Task.Delay(350);
            Check(Vector3.Distance(card.transform.localScale, rootScale) < .001f, "peek keeps root scale stable", results);
            Check(Mathf.Abs(card.transform.Find("CardVisual").localScale.x - 1.2f) < .015f,
                "peek settles at 1.2x (scale=" + card.transform.Find("CardVisual").localScale.x +
                ", frames=" + (Time.frameCount - peekFrame) + ", peek=" + Field(juice, "peek") +
                ", animating=" + Field(juice, "animating") + ")", results);
            Check(card.transform.Find("CardVisual").GetComponent<MeshRenderer>().sortingOrder == 100,
                "peek sorting elevation", results);
            juice.OnPointerUp(null);
            await Task.Delay(350);
            Check(Vector3.Distance(card.transform.Find("CardVisual").localScale, Vector3.one) < .015f,
                "peek restores visual pose", results);

            var contacts = 0;
            juice.StartCoroutine(juice.Fly(home + Vector3.forward * .5f, .22f, false, () => contacts++));
            await Task.Delay(430);
            Check(contacts == 1, "ordinary flight contacts once", results);
            Send(bridge, Snapshot(Table(), Hand()));
            Send(bridge, Capture(generation));
            await Task.Delay(650);
            Check(Cards(bridge).ContainsKey("clubs_six"), "capture ghosts retained during read beat", results);
            await Task.Delay(950);
            Check(Cards(bridge).Count == 3 && !Cards(bridge).ContainsKey("clubs_six"),
                "capture completes with exact accepted visual membership", results);
            Check(Field(bridge, "visualAction") == null, "visual coroutine releases after completion", results);
            Check(Vector3.Distance(camera.transform.position, cameraHome) < .001f, "camera restores after shake", results);
            var particles = Field(bridge, "impactParticles") as ParticleSystem;
            Check(particles != null && particles.main.maxParticles == 16, "capture particles bounded to 16", results);

            Send(bridge, Snapshot(Table(), Hand()));
            generation++;
            Send(bridge, new UnityBridge.MessageData { type = "CANCEL_VISUALS", generation = generation });
            Send(bridge, Capture(generation - 1));
            await Task.Delay(70);
            Check(Cards(bridge).Count == 6 && Field(bridge, "visualAction") == null,
                "old generation ignored", results);
            Send(bridge, Capture(generation, true));
            await Task.Delay(80);
            Check(Cards(bridge).Count == 3 && Field(bridge, "visualAction") == null,
                "reduced motion completes immediately", results);
            Check(Vector3.Distance(camera.transform.position, cameraHome) < .001f && !particles.IsAlive(),
                "reduced motion has no shake or residual burst", results);

            generation++;
            Send(bridge, new UnityBridge.MessageData { type = "CANCEL_VISUALS", generation = generation });
            Send(bridge, Snapshot(Table(), Hand()));
            Send(bridge, Capture(generation));
            await Task.Delay(1120); // Interrupt while root cards are shrinking into the pile.
            generation++;
            Send(bridge, new UnityBridge.MessageData { type = "CANCEL_VISUALS", generation = generation });
            Send(bridge, Snapshot(Table(), Hand()));
            await Task.Delay(120);
            Check(Cards(bridge).Count == 6 && Field(bridge, "visualAction") == null,
                "interrupted collection restores latest snapshot", results);
            Check(Vector3.Distance(Cards(bridge)["clubs_six"].transform.localScale, Vector3.one * 1.5f) < .005f,
                "interrupted collection restores root scale and collider size", results);

            Send(bridge, Snapshot(new List<UnityBridge.CardJson>(), Hand()));
            card = Cards(bridge)["clubs_ace"];
            home = card.transform.position;
            card.transform.position += Vector3.forward * .5f;
            Send(bridge, new UnityBridge.MessageData { type = "INVALID_MOVE", generation = generation, cardId = "clubs_ace" });
            await Task.Delay(350);
            Check(Vector3.Distance(card.transform.position, home) < .005f, "invalid return restores hand anchor", results);
            Check(domain.currentState == originalDomainState, "no legacy rule-state transition", results);
            var sized = Snapshot(Table(), Hand());
            sized.anchors[0].width = .1f; sized.anchors[0].height = .25f;
            sized.anchors[1].width = .08f; sized.anchors[1].height = .18f;
            sized.anchors.Add(new UnityBridge.VisualAnchor { name = "hand0", x = .5f, y = .8f, width = .1f, height = .25f });
            Send(bridge, sized);
            var sizedCard = Cards(bridge)["clubs_six"].transform;
            var lower = camera.WorldToViewportPoint(sizedCard.TransformPoint(new Vector3(0, -.5f, 0)));
            var upper = camera.WorldToViewportPoint(sizedCard.TransformPoint(new Vector3(0, .5f, 0)));
            Check(Mathf.Abs(Vector2.Distance(lower, upper) - .25f) < .01f,
                "sized anchor preserves requested viewport card height", results);
            Check(Vector2.Distance(camera.WorldToViewportPoint(sizedCard.position), new Vector2(.5f, .2f)) < .01f,
                "per-card anchor aligns native input with the logical hand", results);
            Check(tweenWarnings.Count == 0, "no orphan tween target warnings", results);
            Check(runtimeErrors.Count == 0, "no unexpected runtime errors", results);
            return new { passed = results.Count, checks = results.ToArray(), editor = Application.unityVersion };
        } finally {
            if (events != null) events.enabled = eventsEnabled;
            Send(bridge, new UnityBridge.MessageData { type = "CANCEL_VISUALS", generation = generation + 1 });
            Send(bridge, Snapshot(new List<UnityBridge.CardJson>(), new List<UnityBridge.CardJson>()));
            camera.transform.position = cameraHome;
            Application.logMessageReceived -= trackWarnings;
        }
    }
}
