using Studio.OverOne.DragMe.Data.Abstractions;
using UnityEngine.Events;

namespace Studio.OverOne.DragMe.Events
{
    /**
     * * Event raised when the player grabs an object with the Components.DragMe component.
    */
    [System.Serializable]
    public sealed class GrabbedEvent : UnityEvent<IGrabbedEventData>
    {
        /* EMPTY */
    }
}