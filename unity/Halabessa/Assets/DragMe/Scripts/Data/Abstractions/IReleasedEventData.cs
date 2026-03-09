using UnityEngine;

namespace Studio.OverOne.DragMe.Data.Abstractions
{
    public interface IReleasedEventData 
    {
        Components.DragMe ReleasedComponent { get; }

        Vector3 MousePosition { get; }
    }
}