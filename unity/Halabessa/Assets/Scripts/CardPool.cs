using UnityEngine;
using System.Collections.Generic;

public class CardPool : MonoBehaviour {
    public static CardPool Instance;
    
    [SerializeField] private GameObject cardPrefab;
    [SerializeField] private int initialSize = 20;
    
    private Queue<GameObject> pool = new Queue<GameObject>();

    void Awake() {
        Instance = this;
        for (int i = 0; i < initialSize; i++) {
            GameObject obj = Instantiate(cardPrefab);
            obj.SetActive(false);
            pool.Enqueue(obj);
        }
    }

    public GameObject GetCard() {
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
