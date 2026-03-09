using Studio.OverOne.DragMe.Data.Abstractions;
using UnityEngine;

namespace Studio.OverOne.DragMe.Data.Events
{
    public sealed partial class GrabbedEventData : IGrabbedEventData
    {
        // * Reference to the object with the Components.DragMe component that was grabbed.
        public Components.DragMe GrabbedComponent { get; private set; }

        // * The position that the mouse was in when the GrabbedEvent was fired.
        public Vector3 MousePosition { get; private set; }

        public GrabbedEventData(Vector3 location, Components.DragMe component)
        {
            GrabbedComponent = component;
            MousePosition = location;
        }
    }
}