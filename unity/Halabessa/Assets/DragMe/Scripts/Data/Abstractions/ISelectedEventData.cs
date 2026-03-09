using UnityEngine;

namespace Studio.OverOne.DragMe.Data.Abstractions
{
    public interface ISelectedEventData 
    {
        Components.DragMe SelectedComponent { get; }

        Vector3 MousePosition { get; }
    }
}