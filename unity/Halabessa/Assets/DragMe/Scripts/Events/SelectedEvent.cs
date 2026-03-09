using Studio.OverOne.DragMe.Data.Abstractions;
using UnityEngine.Events;

namespace Studio.OverOne.DragMe.Events
{
    /**
     * * Event raised when the mouse hovers over an object with the Components.DragMe component.
    */
    [System.Serializable]
    public sealed class SelectedEvent : UnityEvent<ISelectedEventData>
    {
        /* EMPTY */
    }
}