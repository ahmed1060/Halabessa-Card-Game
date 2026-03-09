using Studio.OverOne.DragMe.Data.Abstractions;
using UnityEngine;

namespace Studio.OverOne.DragMe.Data.Events
{
    public sealed partial class BlockedEventData : IBlockedEventData
    {
        // * Reference to the object with the DragMe component that was blocked.
        public Components.DragMe BlockedComponent { get; private set; }

        // * Reference to the object with the GrabMe component that is blocked.
        public Components.DragMe PlacementComponent { get; private set;}

        // * The position that the mouse was in when the BlockedEvent was fired.
        public Vector3 MousePosition { get; private set; }

        public BlockedEventData(Vector3 mousePosition, Components.DragMe comp, Components.DragMe placementComp)
        {
            BlockedComponent = comp;
            MousePosition = mousePosition;
            PlacementComponent = placementComp;
        }
    }
}