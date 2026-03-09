using UnityEngine;

namespace Studio.OverOne.DragMe.Integrations.Abstractions
{
    public abstract class InputSourceBase : MonoBehaviour
        , IInputSource
    {
        public abstract bool Grab { get; }  

        public abstract bool Hold { get; }

        public abstract bool Release { get; }      
    }
}