using Studio.OverOne.DragMe.Data.Abstractions;
using UnityEngine;

namespace Studio.OverOne.DragMe.Data.Events
{
    public sealed partial class DeselectedEventData : IDeselectedEventData
    {
        // * Reference to the object with the Components.DragMe component that the mouse was hovering over.
        public Components.DragMe DeselectedComponent { get; private set; }

        // * The position that the mouse was in when the DeselectedEvent was fired.
        public Vector3 MousePosition { get; private set; }

        public DeselectedEventData(Vector3 mousePosition, Components.DragMe component)
        {
            DeselectedComponent = component;
            MousePosition = mousePosition;
        }
    }
}