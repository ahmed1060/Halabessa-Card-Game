using Studio.OverOne.DragMe.Data.Abstractions;
using UnityEngine;

namespace Studio.OverOne.DragMe.Data.Events
{
    public sealed partial class ReleasedEventData : IReleasedEventData
    {
        // * Reference to the object with the Components.DragMe component that was released.
        public Components.DragMe ReleasedComponent { get; private set; }

        // * The position that the mouse was in when the ReleasedEvent was fired.
        public Vector3 MousePosition { get; private set; }

        public ReleasedEventData(Vector3 mousePosition, Components.DragMe component)
        {
            ReleasedComponent = component;
            MousePosition = mousePosition;
        }
    }
}