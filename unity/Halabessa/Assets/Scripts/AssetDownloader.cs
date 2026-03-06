using UnityEngine;
using UnityEngine.Networking;
using System.Collections;

public class AssetDownloader : MonoBehaviour {
    public static AssetDownloader Instance;

    void Awake() {
        Instance = this;
    }

    public void RequestTextureFromFlutter(string url, System.Action<Texture2D> callback) {
        StartCoroutine(DownloadTexture(url, callback));
    }

    private IEnumerator DownloadTexture(string url, System.Action<Texture2D> callback) {
        using (UnityWebRequest uwr = UnityWebRequestTexture.GetTexture(url)) {
            yield return uwr.SendWebRequest();

            if (uwr.result != UnityWebRequest.Result.Success) {
                Debug.LogError("Unity: Error downloading texture: " + uwr.error);
            } else {
                Texture2D tex = DownloadHandlerTexture.GetContent(uwr);
                callback?.Invoke(tex);
            }
        }
    }
}
