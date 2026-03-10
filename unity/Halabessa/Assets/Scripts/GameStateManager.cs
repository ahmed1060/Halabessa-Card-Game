using UnityEngine;
using System.Collections;
using System.Collections.Generic;
using FlutterUnityIntegration;

public class GameStateManager : MonoBehaviour {
    public enum GameState { IDLE, PLAYER_TURN, CALCULATING_CAPTURE, BASRA_CHECK, OPPONENT_TURN, CELEBRATION }
    public static GameStateManager Instance;
    
    public GameState currentState = GameState.IDLE;
    public enum GameMode { CLASSIC, TAFWEET }
    public GameMode currentMode = GameMode.CLASSIC;

    private List<string> boardCards = new List<string>();
    
    void Awake() {
        if (Instance == null) Instance = this;
        else Destroy(gameObject);
    }

    public void SetMode(string mode) {
        currentMode = (mode == "tafweet") ? GameMode.TAFWEET : GameMode.CLASSIC;
    }

    public void SetBoard(List<string> cards) {
        boardCards = cards;
    }

    public List<string> CalculateCapture(string playedCardRank, string playedCardId) {
        if (currentMode == GameMode.TAFWEET) {
            // In Tafweet, standard capture rules might be inverted or modified.
            // Placeholder for Tafweet specific logic
            boardCards.Add(playedCardId);
            return new List<string>();
        }

        if (boardCards.Count == 0) {
            boardCards.Add(playedCardId);
            return new List<string>();
        }

        // Halabessa Rule: Last card on board (top) matches played card rank
        string topCardId = boardCards[boardCards.Count - 1];
        string topCardRank = topCardId.Split('_')[0];
        
        if (playedCardRank == topCardRank) {
            // Sweep entire board
            List<string> captured = new List<string>(boardCards);
            captured.Add(playedCardId);
            boardCards.Clear();
            
            if (captured.Count > 1) { 
                // Potential Basra or match win
                ChangeState(GameState.CELEBRATION);
            }
            
            return captured;
        }

        boardCards.Add(playedCardId);
        return new List<string>();
    }
    
    public void ChangeState(GameState newState) {
        currentState = newState;
        // Debug.Log("Game State Changed to: " + newState);
        
        switch (newState) {
            case GameState.PLAYER_TURN:
                // Enable UI interaction
                break;
            case GameState.CALCULATING_CAPTURE:
                // Start capture animation logic
                break;
            case GameState.BASRA_CHECK:
                // Check if the sweep was a Basra
                break;
        }
        
        // Notify Flutter of state change if needed
        UnityMessageManager.Instance.SendMessageToFlutter("STATE_CHANGED:" + newState.ToString());
    }
    
    public GameState GetCurrentState() => currentState;
}
