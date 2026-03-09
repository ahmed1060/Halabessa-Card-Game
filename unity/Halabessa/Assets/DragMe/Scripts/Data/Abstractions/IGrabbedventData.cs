using UnityEngine;

namespace Studio.OverOne.DragMe.Data.Abstractions
{
    public interface IGrabbedEventData 
    {
        Components.DragMe GrabbedComponent { get; }

        Vector3 MousePosition { get; }
    }
}