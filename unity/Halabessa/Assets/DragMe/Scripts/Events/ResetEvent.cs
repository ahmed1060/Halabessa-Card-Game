using Studio.OverOne.DragMe.Data.Abstractions;
using UnityEngine.Events;

namespace Studio.OverOne.DragMe.Events
{
    /**
     * * Event raised when an object with the DragMe component has been reset.
    */
    [System.Serializable]
    public sealed class ResetEvent : UnityEvent<IResetEventData>
    {
        /* EMPTY */
    }
}