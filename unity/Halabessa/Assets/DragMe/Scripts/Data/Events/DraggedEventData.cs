using Studio.OverOne.DragMe.Data.Abstractions;
using UnityEngine;

namespace Studio.OverOne.DragMe.Data.Events
{
    public sealed partial class DraggedEventData : IDraggedEventData
    {
        // * Reference to the object with the Components.DragMe component that is currently being dragged.
        public Components.DragMe DraggedComponent { get; private set; }

        // * The position that the mouse was in when the last DraggedEvent was fired.
        public Vector3 PreviousMousePosition { get; private set; }

        // * The position that the mouse is in currently when the DraggedEvent was fired.
        public Vector3 CurrentMousePosition { get; private set; }

        public DraggedEventData(Vector3 prevMousePosition, Vector3 currMousePosition, Components.DragMe component)
        {
            DraggedComponent = component;
            PreviousMousePosition = prevMousePosition;
            CurrentMousePosition = currMousePosition;
        }
    }
}