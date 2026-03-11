using UnityEngine;
using System.Collections.Generic;

public class CardPool : MonoBehaviour {
    public static CardPool Instance;
    
    [SerializeField] private int initialSize = 20;
    
    private GameObject cardPrefab;
    private Queue<GameObject> pool = new Queue<GameObject>();

    void Awake() {
        Instance = this;
        // Load from Resources to match UnityBridge and survive WebGL Inspector stripping
        cardPrefab = Resources.Load<GameObject>("CardPrefab");
        if (cardPrefab == null) {
            Debug.LogError("CardPool: CardPrefab not found in Resources folder. Pool will not be initialized.");
            return;
        }
        for (int i = 0; i < initialSize; i++) {
            GameObject obj = Instantiate(cardPrefab);
            obj.SetActive(false);
            pool.Enqueue(obj);
        }
    }

    public GameObject GetCard() {
        if (cardPrefab == null) return null;
        if (pool.Count > 0) {
            GameObject obj = pool.Dequeue();
            obj.SetActive(true);
            return obj;
        } else {
            return Instantiate(cardPrefab);
        }
    }

    public void ReturnCard(GameObject card) {
        card.SetActive(false);
        pool.Enqueue(card);
    }
}
