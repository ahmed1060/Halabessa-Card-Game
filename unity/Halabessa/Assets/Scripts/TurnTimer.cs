using UnityEngine;
using UnityEngine.UI;
using TMPro;

public class TurnTimer : MonoBehaviour {
    public static TurnTimer Instance;

    [SerializeField] private Image timerFill;
    [SerializeField] private TextMeshProUGUI timerText;
    
    private float timeRemaining;
    private float totalTime;
    private bool isRunning;

    void Awake() {
        Instance = this;
    }

    public void StartTimer(float duration) {
        totalTime = duration;
        timeRemaining = duration;
        isRunning = true;
        gameObject.SetActive(true);
    }

    public void StopTimer() {
        isRunning = false;
        gameObject.SetActive(false);
    }

    void Update() {
        if (!isRunning) return;

        timeRemaining -= Time.deltaTime;
        if (timeRemaining <= 0) {
            timeRemaining = 0;
            isRunning = false;
            // Optionally notify Flutter that time is up if Unity is authoritative for timer
        }

        if (timerFill != null) {
            timerFill.fillAmount = timeRemaining / totalTime;
            // Optional: Color gradient from green to red
            timerFill.color = Color.Lerp(Color.red, Color.green, timeRemaining / totalTime);
        }

        if (timerText != null) {
            timerText.text = Mathf.CeilToInt(timeRemaining).ToString();
        }
    }
}
