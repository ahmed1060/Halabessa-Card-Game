using Studio.OverOne.DragMe.Data.Abstractions;
using UnityEngine.Events;

namespace Studio.OverOne.DragMe.Events
{
    /**
     * * Event raised when an object with the DragMe component is no longer grabbed.
    */
    [System.Serializable]
    public sealed class ReleasedEvent : UnityEvent<IReleasedEventData>
    {
        /* EMPTY */
    }
}