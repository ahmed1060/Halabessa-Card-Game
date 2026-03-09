using UnityEngine;

namespace Studio.OverOne.DragMe.Data.Abstractions
{
    public interface IBlockedEventData 
    {
        Components.DragMe BlockedComponent { get; }

        Components.DragMe PlacementComponent { get; }

        Vector3 MousePosition { get; }
    }
}