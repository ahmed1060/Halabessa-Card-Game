using UnityEngine;

public class AudioManager : MonoBehaviour {
    public static AudioManager Instance;

    [SerializeField] private AudioSource sfxSource;
    
    [Header("Clips")]
    public AudioClip cardFly;
    public AudioClip capture;
    public AudioClip basra;

    void Awake() {
        if (Instance == null) Instance = this;
    }

    public void PlayCardFly() {
        sfxSource.PlayOneShot(cardFly);
    }

    public void PlayCapture() {
        sfxSource.PlayOneShot(capture);
    }

    public void PlayBasra() {
        sfxSource.PlayOneShot(basra);
    }
}
