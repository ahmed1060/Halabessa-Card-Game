using UnityEngine;

namespace Studio.OverOne.DragMe.Data.Abstractions
{
    public interface IPlacedEventData 
    {
        Components.DragMe PlacedComponent { get; }

        Components.DragMe PlacementComponent { get; }

        Vector3 MousePosition { get; }
    }
}