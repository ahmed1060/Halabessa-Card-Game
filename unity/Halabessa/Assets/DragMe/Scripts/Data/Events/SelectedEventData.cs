using Studio.OverOne.DragMe.Data.Abstractions;
using UnityEngine;

namespace Studio.OverOne.DragMe.Data.Events
{
    public sealed partial class SelectedEventData : ISelectedEventData
    {
        // * Reference to the object with the Components.DragMe component that the mouse is hovering over.
        public Components.DragMe SelectedComponent { get; private set; }

        // * The position that the mouse was in when the SelectedEvent was fired.
        public Vector3 MousePosition { get; private set; }

        public SelectedEventData(Vector3 mousePosition, Components.DragMe component)
        {
            SelectedComponent = component;
            MousePosition = mousePosition;
        }
    }
}