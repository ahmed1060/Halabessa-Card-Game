using UnityEngine;

public class CelebrationManager : MonoBehaviour {
    public static CelebrationManager Instance;

    [SerializeField] private ParticleSystem winConfetti;
    [SerializeField] private ParticleSystem basraSparkles;

    void Awake() {
        Instance = this;
    }

    public void PlayWinEffect() {
        if (winConfetti != null) winConfetti.Play();
        // Add more grandiose effects here
        Debug.Log("Unity VFX: Playing Match Win Celebration!");
    }

    public void PlayBasraEffect() {
        if (basraSparkles != null) basraSparkles.Play();
        Debug.Log("Unity VFX: Playing Basra Sparkles!");
    }
}
