#pragma warning disable 0649 // Never assigned to and will always have its default value.

using UnityEngine;
using UnityEngine.SceneManagement;

namespace Studio.OverOne.DragMe.Demo
{
    public class SceneLoader : MonoBehaviour
    {
        #region " Inspector Variables "

        [SerializeField] private string _previousSceneName;

        [SerializeField] private string _nextSceneName;

        #endregion

        public void Back()
        {
            SceneManager.LoadScene(_previousSceneName);
        }

        public void Next()
        {
            SceneManager.LoadScene(_nextSceneName);
        }
    }
}