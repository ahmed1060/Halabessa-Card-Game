using UnityEngine;

namespace Studio.OverOne.DragMe.Data.Abstractions
{
    public interface IDraggedEventData 
    {
        Components.DragMe DraggedComponent { get; }

        Vector3 PreviousMousePosition { get; }

        Vector3 CurrentMousePosition { get; }
    }
}