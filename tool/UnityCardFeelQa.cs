// Explicit local Pipeline run_script harness. Outside Assets: never shipped/imported.
using System;
using System.Collections;
using System.Threading.Tasks;
using UnityEngine;

public static class UnityCardFeelQa {
    private static void Check(bool value, string message) {
        if (!value) throw new InvalidOperationException(message);
    }
    private static IEnumerator Observe(IEnumerator animation, Action done) {
        yield return animation; done();
    }
    public static async Task<object> Run() {
        Check(Application.isPlaying, "Run only in temporary Play Mode.");
        var background = Application.runInBackground;
        Application.runInBackground = true; // QA only; never changes PlayerSettings.
        try {
        var bridge = UnityBridge.Instance;
        Check(bridge != null, "Existing game scene must contain UnityBridge.");
        var generation = (int)typeof(UnityBridge).GetField("visualGeneration",
            System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic).GetValue(bridge) + 1;
        void Send(string json) {
            var data = JsonUtility.FromJson<UnityBridge.MessageData>(json);
            if (data.generation >= 79 && data.generation <= 81) data.generation += generation - 80;
            bridge.OnFlutterMessage(JsonUtility.ToJson(data));
        }
        Send("{\"type\":\"CANCEL_VISUALS\",\"generation\":80}");
        Send("{\"type\":\"SYNC_STATE\",\"instant\":true,\"board\":[],\"handCards\":[{\"suit\":\"clubs\",\"rank\":\"six\"}],\"anchors\":[{\"name\":\"hand\",\"x\":0.5,\"y\":0.8,\"width\":0.07,\"height\":0.15}]}");
        await Task.Delay(120);
        var root = GameObject.Find("Hand_clubs_six");
        Check(root != null, "Managed hand card was not spawned.");
        var juice = root.GetComponent<CardJuiceController>();
        var colliderCount = root.GetComponentsInChildren<Collider>().Length;
        Send("{\"type\":\"HAND_SELECTION\",\"generation\":80,\"cardId\":\"clubs_six\",\"queued\":true,\"slam\":true}");
        juice.SetHandPose(false, 0, 0);
        await Task.Delay(200);
        var visual = root.transform.Find("CardVisual");
        var rim = visual.Find("PrivateSelectionRim").GetComponent<LineRenderer>();
        var doubleRim = visual.Find("PrivateSlamRim").GetComponent<LineRenderer>();
        Check(rim.enabled && doubleRim.enabled && visual.localScale.x > 1.15f,
            "Queued slam cue did not survive hover exit.");
        Check(root.GetComponentsInChildren<Collider>().Length == colliderCount,
            "Private cue changed card input colliders.");
        Send("{\"type\":\"HAND_SELECTION\",\"generation\":79,\"cardId\":\"clubs_six\",\"queued\":false}");
        await Task.Delay(40);
        Check(rim.enabled && doubleRim.enabled, "Stale selection message mutated current cue.");
        Send("{\"type\":\"HAND_SELECTION\",\"generation\":80,\"cardId\":\"clubs_six\",\"queued\":false,\"slam\":false}");
        await Task.Delay(100);
        Check(!rim.enabled && !doubleRim.enabled, "Short-tap cancellation did not remove cue.");
        var started = Time.realtimeSinceStartup;
        var contactCount = 0; var contactAt = 0f;
        var target = root.transform.position + Vector3.right * .2f;
        var completion = new TaskCompletionSource<bool>();
        juice.StartCoroutine(Observe(juice.Fly(target, .2f, true,
            () => { contactCount++; contactAt = Time.realtimeSinceStartup - started; },
            null, true), () => completion.TrySetResult(true)));
        await completion.Task;
        var elapsed = Time.realtimeSinceStartup - started;
        Check(contactCount == 1 && contactAt >= .24f && contactAt < .45f,
            "Gesture slam contact must fire once near 270 ms.");
        Check(elapsed >= .44f && elapsed < 1.2f && Vector3.Distance(root.transform.position, target) < .001f,
            "Slam must settle at the intended target with a bounded duration.");
        juice.ReducedMotion = true;
        var reduced = new TaskCompletionSource<bool>(); contactCount = 0;
        juice.StartCoroutine(Observe(juice.Fly(target, 0, true, () => contactCount++, null, true),
            () => reduced.TrySetResult(true)));
        await reduced.Task;
        Check(contactCount == 1, "Reduced motion lost or duplicated contact.");
        Send("{\"type\":\"CANCEL_VISUALS\",\"generation\":81}");
        Send("{\"type\":\"SYNC_STATE\",\"instant\":true,\"board\":[],\"handCards\":[]}");
        return new { passed = true, checks = 8, contactMs = contactAt * 1000,
            totalMs = elapsed * 1000, sceneSaved = false };
        } finally { Application.runInBackground = background; }
    }
}
