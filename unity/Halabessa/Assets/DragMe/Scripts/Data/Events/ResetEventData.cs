using Studio.OverOne.DragMe.Data.Abstractions;
using UnityEngine;

namespace Studio.OverOne.DragMe.Data.Events
{
    public sealed partial class ResetEventData : IResetEventData
    {
        // * Reference to the DragMe component that was reset.
        public Components.DragMe ResetComponent { get; private set; }

        // * The position that the mouse was in when the ReleasedEvent was fired.
        public Vector3 MousePosition { get; private set; }

        public ResetEventData(Vector3 mousePosition, Components.DragMe comp)
        {
            ResetComponent = comp;
            MousePosition = mousePosition;
        }
    }
}