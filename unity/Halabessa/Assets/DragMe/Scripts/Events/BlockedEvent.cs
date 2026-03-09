using Studio.OverOne.DragMe.Data.Abstractions;
using UnityEngine.Events;

namespace Studio.OverOne.DragMe.Events
{
    /**
     * * Event raised when the player attempts to place an object with the Components.DragMe component on an object with a blocked Placement component.
    */
    [System.Serializable]
    public sealed class BlockedEvent : UnityEvent<IBlockedEventData>
    {
        /* EMPTY */
    }
}