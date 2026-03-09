using UnityEngine;

namespace Studio.OverOne.DragMe.Data.Abstractions
{
    public interface IDeselectedEventData 
    {
        Components.DragMe DeselectedComponent { get; }

        Vector3 MousePosition { get; }
    }
}