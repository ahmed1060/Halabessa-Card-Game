using Studio.OverOne.DragMe.Data.Abstractions;
using UnityEngine;

namespace Studio.OverOne.DragMe.Data.Events
{
    public sealed partial class PlacedEventData : IPlacedEventData
    {
        // * Reference to the object with the DragMe component that the mouse released.
        public Components.DragMe PlacedComponent { get; private set; }

        // * Reference to the object with the DragMe component that the PlacedComponent has been placed.
        public Components.DragMe PlacementComponent { get; private set; }

        // * The position that the mouse was in when the PlacedEvent was fired.
        public Vector3 MousePosition { get; private set; }

        public PlacedEventData(Vector3 mousePosition, Components.DragMe comp, Components.DragMe placementComp)
        {
            PlacedComponent = comp;
            MousePosition = mousePosition;
            PlacementComponent = placementComp;
        }
    }
}