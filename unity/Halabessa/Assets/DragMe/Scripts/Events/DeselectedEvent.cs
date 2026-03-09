using Studio.OverOne.DragMe.Data.Abstractions;
using UnityEngine.Events;

namespace Studio.OverOne.DragMe.Events
{
    /**
     * * Event raised when a hovering mouse no longer hovers over an object with the GrabbedMe component.
    */
    [System.Serializable]
    public sealed class DeselectedEvent : UnityEvent<IDeselectedEventData>
    {
        /* EMPTY */
    }
}