using UnityEngine;
using TMPro; // Assuming TextMeshPro is used for professional UI

public class FSMStateVisualizer : MonoBehaviour {
    [SerializeField] private TextMeshProUGUI stateText;
    
    void Update() {
        if (stateText != null && GameStateManager.Instance != null) {
            stateText.text = "FSM State: " + GameStateManager.Instance.currentState.ToString();
            
            // Color coding for states
            switch (GameStateManager.Instance.currentState) {
                case GameStateManager.GameState.PLAYER_TURN:
                    stateText.color = Color.green;
                    break;
                case GameStateManager.GameState.CALCULATING_CAPTURE:
                    stateText.color = Color.yellow;
                    break;
                case GameStateManager.GameState.IDLE:
                    stateText.color = Color.white;
                    break;
                default:
                    stateText.color = Color.cyan;
                    break;
            }
        }
    }
}
