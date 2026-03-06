using UnityEngine;
#if !UNITY_WEBGL || UNITY_EDITOR
using Firebase;
using Firebase.Database;
using Firebase.Extensions;
#endif

public class UnityFirebaseListener : MonoBehaviour {
#if !UNITY_WEBGL || UNITY_EDITOR
    DatabaseReference reference;

    void Start() {
        FirebaseApp.CheckAndFixDependenciesAsync().ContinueWithOnMainThread(task => {
            if (task.Result == DependencyStatus.Available) {
                InitializeFirebase();
            } else {
                Debug.LogError("Could not resolve all Firebase dependencies: " + task.Result);
            }
        });
    }

    void InitializeFirebase() {
        // Set this to your match ID dynamically via Flutter call
        string matchId = "temp_match_id"; 
        reference = FirebaseDatabase.DefaultInstance.GetReference("matches").Child(matchId).Child("board");

        reference.ValueChanged += HandleBoardChanged;
    }

    void HandleBoardChanged(object sender, ValueChangedEventArgs args) {
        if (args.DatabaseError != null) {
            Debug.LogError(args.DatabaseError.Message);
            return;
        }
        
        // DataSnapshot contains the new board state
        // Use this to trigger DOTween animations if a new card was added
        Debug.Log("Unity: Firebase Board Stream Updated!");
    }

    void OnDestroy() {
        if (reference != null) {
            reference.ValueChanged -= HandleBoardChanged;
        }
    }
#else
    void Start() {
        Debug.Log("Unity: Firebase C# SDK is disabled on WebGL. Using Flutter Bridge for data.");
    }
#endif
}
