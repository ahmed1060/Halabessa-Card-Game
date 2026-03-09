using UnityEngine;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine.SceneManagement;

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
        goManager.AddComponent<TurnTimer>();
        goManager.AddComponent<CelebrationManager>();

        // 4. Create UnityBridge
        GameObject goBridge = new GameObject("UnityBridge");
        goBridge.AddComponent<UnityBridge>();

        // 5. Create DeckManager
        GameObject goDeck = new GameObject("DeckManager");
        goDeck.AddComponent<DeckManager>();

        // 6. Create Firebase Listener
        GameObject goFirebase = new GameObject("FirebaseListener");
        goFirebase.AddComponent<UnityFirebaseListener>();

        // 7. Create Asset Downloader
        GameObject goDownloader = new GameObject("AssetDownloader");
        goDownloader.AddComponent<AssetDownloader>();

        // 8. Create a Professional Card Prefab (A Quad with correct poker aspect ratio)
        if (!AssetDatabase.IsValidFolder("Assets/Resources")) {
            AssetDatabase.CreateFolder("Assets", "Resources");
        }
        
        GameObject dummyCard = GameObject.CreatePrimitive(PrimitiveType.Quad);
        dummyCard.name = "CardPrefab";
        // Poker card aspect ratio is 2.5 x 3.5. We use 2.0 x 2.8.
        dummyCard.transform.localScale = new Vector3(2f, 2.8f, 1f); 
        // Laying flat, but slightly elevated so it doesn't clip
        dummyCard.transform.rotation = Quaternion.Euler(90, 0, 0); 

        // 8.1 Add Fake Shadow child
        GameObject shadow = GameObject.CreatePrimitive(PrimitiveType.Quad);
        shadow.name = "Shadow";
        shadow.transform.SetParent(dummyCard.transform);
        // Slightly offset down and shifted
        shadow.transform.localPosition = new Vector3(0.05f, -0.01f, -0.05f); 
        shadow.transform.localScale = Vector3.one; // Relative to parent
        shadow.transform.localRotation = Quaternion.identity;
        
        // Remove collider from shadow
        if (shadow.GetComponent<Collider>()) DestroyImmediate(shadow.GetComponent<Collider>());

        // Create a simple shadow material
        Material shadowMat = new Material(Shader.Find("Transparent/Diffuse"));
        shadowMat.color = new Color(0, 0, 0, 0.4f);
        shadow.GetComponent<Renderer>().material = shadowMat;
        
        // 9. Add CardInstance logic script for DOTween animations
        CardInstance cardInstance = dummyCard.AddComponent<CardInstance>();
        
        // Save the dummy prefab
        PrefabUtility.SaveAsPrefabAsset(dummyCard, "Assets/Resources/CardPrefab.prefab");
        DestroyImmediate(dummyCard); // Remove from scene after making prefab

        // Note: We completely removed the 3D Table Plane!
        // The Flutter glowing UI will now serve as the table natively.

        // 10. Save the Scene
        EditorSceneManager.SaveScene(newScene, "Assets/GameScene.unity");

        // 11. Add to Build Settings automatically
        EditorBuildSettingsScene[] original = EditorBuildSettings.scenes;
        EditorBuildSettingsScene[] newSettings = new EditorBuildSettingsScene[1];
        newSettings[0] = new EditorBuildSettingsScene("Assets/GameScene.unity", true);
        EditorBuildSettings.scenes = newSettings;

        Debug.Log("✅ Halabessa Auto-Build Complete! GameScene generated with casino table, camera, and all logic managers attached.");
    }
}
