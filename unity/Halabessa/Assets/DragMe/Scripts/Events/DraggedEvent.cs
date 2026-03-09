using Studio.OverOne.DragMe.Data.Abstractions;
using UnityEngine.Events;

namespace Studio.OverOne.DragMe.Events
{
    /**
     * * Event raised when an object with the Components.DragMe component is moved.
    */
    [System.Serializable]
    public sealed class DraggedEvent : UnityEvent<IDraggedEventData>
    {
        /* EMPTY */
    }
}