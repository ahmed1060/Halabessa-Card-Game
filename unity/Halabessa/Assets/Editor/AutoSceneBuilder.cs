using UnityEngine;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine.SceneManagement;
using UnityEngine.EventSystems;
using UnityEngine.UI;
using TMPro;

public class AutoSceneBuilder : EditorWindow
{
    [MenuItem("Halabessa/Auto-Build Scene (Fast Fix)")]
    public static void BuildBaseScene()
    {
        // 1. Create a new empty scene
        Scene newScene = EditorSceneManager.NewScene(NewSceneSetup.DefaultGameObjects, NewSceneMode.Single);

        // 2. Setup Camera for Transparent WebGL Overlay
        Camera mainCam = Camera.main;
        // Position camera higher to view the whole board
        mainCam.transform.position = new Vector3(0, 8, -6);
        mainCam.transform.rotation = Quaternion.Euler(55, 0, 0); // Steeper angle
        // CRITICAL FOR TRANSPARENCY: Alpha must be 0!
        mainCam.backgroundColor = new Color(0f, 0f, 0f, 0f);   
        mainCam.clearFlags = CameraClearFlags.SolidColor;

        // Add proper lighting so cards look professional
        RenderSettings.ambientLight = new Color(0.6f, 0.6f, 0.6f);
        GameObject dirLight = new GameObject("Directional Light");
        Light lightComp = dirLight.AddComponent<Light>();
        lightComp.type = LightType.Directional;
        lightComp.intensity = 1.2f;
        dirLight.transform.rotation = Quaternion.Euler(50, -30, 0);

        // 3. Create GameManager
        GameObject goManager = new GameObject("GameManager");
        goManager.AddComponent<GameStateManager>();
        TurnTimer turnTimer = goManager.AddComponent<TurnTimer>();
        goManager.AddComponent<CelebrationManager>();
        // Previously never added to the scene at all -- its [SerializeField]
        // stateText stayed null and the debug FSM label never appeared.
        FSMStateVisualizer fsmVisualizer = goManager.AddComponent<FSMStateVisualizer>();

        // 3.1 EventSystem + PhysicsRaycaster. Without these, CardInstance's
        // DragMe component never receives pointer events at all -- the 3D
        // hand renders but e_Released (the only path that emits PLAY_CARD
        // back to Flutter) can never fire.
        GameObject goEventSystem = new GameObject("EventSystem");
        goEventSystem.AddComponent<EventSystem>();
        goEventSystem.AddComponent<StandaloneInputModule>();
        mainCam.gameObject.AddComponent<PhysicsRaycaster>();

        // 4. Create UnityBridge
        GameObject goBridge = new GameObject("UnityBridge");
        goBridge.AddComponent<UnityBridge>();

        // 5. Create DeckManager
        GameObject goDeck = new GameObject("DeckManager");
        goDeck.AddComponent<DeckManager>();

        // 6. Create Asset Downloader. Networking and authentication stay in
        // Flutter; Unity is a deterministic presentation client fed through
        // UnityBridge. Keeping a second backend client in the scene caused
        // divergent state and bundled an unnecessary native Firebase SDK.
        GameObject goDownloader = new GameObject("AssetDownloader");
        goDownloader.AddComponent<AssetDownloader>();

        // 7. Create a Professional Card Prefab (A Quad with correct poker aspect ratio)
        if (!AssetDatabase.IsValidFolder("Assets/Resources")) {
            AssetDatabase.CreateFolder("Assets", "Resources");
        }
        
        GameObject dummyCard = GameObject.CreatePrimitive(PrimitiveType.Quad);
        dummyCard.name = "CardPrefab";
        // Poker card aspect ratio is 2.5 x 3.5. We use 2.0 x 2.8.
        dummyCard.transform.localScale = new Vector3(2f, 2.8f, 1f); 
        // Laying flat, but slightly elevated so it doesn't clip
        dummyCard.transform.rotation = Quaternion.Euler(90, 0, 0); 

        // 7.1 Add Fake Shadow child
        GameObject shadow = GameObject.CreatePrimitive(PrimitiveType.Quad);
        shadow.name = "Shadow";
        shadow.transform.SetParent(dummyCard.transform);
        // Slightly offset down and shifted
        shadow.transform.localPosition = new Vector3(0.05f, -0.01f, -0.05f); 
        shadow.transform.localScale = Vector3.one; // Relative to parent
        shadow.transform.localRotation = Quaternion.identity;
        
        // Remove collider from shadow
        if (shadow.GetComponent<Collider>()) DestroyImmediate(shadow.GetComponent<Collider>());

        // Create a simple shadow material. Sprites/Default instead of the
        // legacy Transparent/Diffuse: legacy built-in shaders are only kept
        // in a player build if they're in Graphics > Always Included
        // Shaders, which this one wasn't -- it rendered magenta (Unity's
        // "shader missing" fallback) in the WebGL build despite looking
        // correct in the editor. Sprites/Default ships with Unity's core
        // resources, is never stripped, and honors material.color alpha.
        Material shadowMat = new Material(Shader.Find("Sprites/Default"));
        shadowMat.color = new Color(0, 0, 0, 0.4f);
        shadow.GetComponent<Renderer>().material = shadowMat;
        
        // 8. Add CardInstance logic script for DOTween animations
        CardInstance cardInstance = dummyCard.AddComponent<CardInstance>();
        
        // Save the dummy prefab
        PrefabUtility.SaveAsPrefabAsset(dummyCard, "Assets/Resources/CardPrefab.prefab");
        DestroyImmediate(dummyCard); // Remove from scene after making prefab

        // Note: We completely removed the 3D Table Plane!
        // The Flutter glowing UI will now serve as the table natively.

        // 8.1 Screen-space UI Canvas for the turn timer and the FSM debug
        // label. Previously there was no Canvas anywhere in the generated
        // scene, so TurnTimer.timerFill/timerText and
        // FSMStateVisualizer.stateText stayed null forever.
        GameObject goCanvas = new GameObject("GameCanvas");
        Canvas canvas = goCanvas.AddComponent<Canvas>();
        canvas.renderMode = RenderMode.ScreenSpaceOverlay;
        CanvasScaler scaler = goCanvas.AddComponent<CanvasScaler>();
        scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
        scaler.referenceResolution = new Vector2(1920, 1080);
        goCanvas.AddComponent<GraphicRaycaster>();

        GameObject goTimerFill = new GameObject("TimerFill", typeof(RectTransform));
        goTimerFill.transform.SetParent(goCanvas.transform, false);
        Image timerFill = goTimerFill.AddComponent<Image>();
        timerFill.type = Image.Type.Filled;
        timerFill.fillMethod = Image.FillMethod.Radial360;
        RectTransform timerFillRect = goTimerFill.GetComponent<RectTransform>();
        timerFillRect.anchorMin = timerFillRect.anchorMax = new Vector2(0.5f, 0f);
        timerFillRect.anchoredPosition = new Vector2(0, 120);
        timerFillRect.sizeDelta = new Vector2(120, 120);

        GameObject goTimerText = new GameObject("TimerText", typeof(RectTransform));
        goTimerText.transform.SetParent(goTimerFill.transform, false);
        TextMeshProUGUI timerText = goTimerText.AddComponent<TextMeshProUGUI>();
        timerText.alignment = TextAlignmentOptions.Center;
        timerText.fontSize = 36;
        RectTransform timerTextRect = goTimerText.GetComponent<RectTransform>();
        timerTextRect.anchorMin = Vector2.zero;
        timerTextRect.anchorMax = Vector2.one;
        timerTextRect.offsetMin = timerTextRect.offsetMax = Vector2.zero;

        GameObject goFsmLabel = new GameObject("FSMStateLabel", typeof(RectTransform));
        goFsmLabel.transform.SetParent(goCanvas.transform, false);
        TextMeshProUGUI fsmText = goFsmLabel.AddComponent<TextMeshProUGUI>();
        fsmText.alignment = TextAlignmentOptions.TopLeft;
        fsmText.fontSize = 24;
        RectTransform fsmRect = goFsmLabel.GetComponent<RectTransform>();
        fsmRect.anchorMin = fsmRect.anchorMax = fsmRect.pivot = new Vector2(0, 1);
        fsmRect.anchoredPosition = new Vector2(20, -20);
        fsmRect.sizeDelta = new Vector2(400, 60);

        // Wire the Canvas elements into TurnTimer/FSMStateVisualizer's
        // private [SerializeField] fields -- there's no public setter, and
        // this is the standard editor-time way to assign a serialized
        // reference without one.
        SerializedObject soTimer = new SerializedObject(turnTimer);
        soTimer.FindProperty("timerFill").objectReferenceValue = timerFill;
        soTimer.FindProperty("timerText").objectReferenceValue = timerText;
        soTimer.ApplyModifiedPropertiesWithoutUndo();

        SerializedObject soFsm = new SerializedObject(fsmVisualizer);
        soFsm.FindProperty("stateText").objectReferenceValue = fsmText;
        soFsm.ApplyModifiedPropertiesWithoutUndo();

        // 9. Save the Scene
        EditorSceneManager.SaveScene(newScene, "Assets/GameScene.unity");

        // 10. Add to Build Settings automatically
        EditorBuildSettingsScene[] original = EditorBuildSettings.scenes;
        EditorBuildSettingsScene[] newSettings = new EditorBuildSettingsScene[1];
        newSettings[0] = new EditorBuildSettingsScene("Assets/GameScene.unity", true);
        EditorBuildSettings.scenes = newSettings;

        Debug.Log("✅ Halabessa Auto-Build Complete! GameScene generated with casino table, camera, and all logic managers attached.");
    }
}
