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

        // 2. Setup Camera
        Camera mainCam = Camera.main;
        mainCam.transform.position = new Vector3(0, 10, -10);
        mainCam.transform.rotation = Quaternion.Euler(45, 0, 0); // Looking down at table
        mainCam.backgroundColor = new Color(0.1f, 0.3f, 0.1f);   // Casino Green background
        mainCam.clearFlags = CameraClearFlags.SolidColor;

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

        // 8. Create a Dummy Card Prefab (A simple Quad)
        if (!AssetDatabase.IsValidFolder("Assets/Resources")) {
            AssetDatabase.CreateFolder("Assets", "Resources");
        }
        
        GameObject dummyCard = GameObject.CreatePrimitive(PrimitiveType.Quad);
        dummyCard.name = "CardPrefab";
        dummyCard.transform.localScale = new Vector3(2f, 3f, 1f); // Card proportions
        dummyCard.transform.rotation = Quaternion.Euler(90, 0, 0); // Laying flat
        dummyCard.AddComponent<CardInstance>();
        
        // Save the dummy prefab
        PrefabUtility.SaveAsPrefabAsset(dummyCard, "Assets/Resources/CardPrefab.prefab");
        DestroyImmediate(dummyCard); // Remove from scene after making prefab

        // 9. Create a Table visual (A large Plane)
        GameObject table = GameObject.CreatePrimitive(PrimitiveType.Plane);
        table.name = "TableTop";
        table.transform.position = Vector3.zero;
        table.transform.localScale = new Vector3(2, 1, 2);
        
        // Add a dark material to table
        Material mat = new Material(Shader.Find("Standard"));
        mat.color = new Color(0.2f, 0.2f, 0.2f);
        table.GetComponent<Renderer>().sharedMaterial = mat;

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
