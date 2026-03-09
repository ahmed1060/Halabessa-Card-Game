using UnityEngine;

namespace Studio.OverOne.DragMe.Data.Abstractions
{
    public interface ITransformData 
    {
        Components.DragMe Parent { get; }

        Vector3 WorldPosition { get; }
    }
}