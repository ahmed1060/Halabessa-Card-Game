using Studio.OverOne.DragMe.Data.Abstractions;
using UnityEngine;

namespace Studio.OverOne.DragMe.Data 
{
    public sealed class TransformData : ITransformData
    {
        public Components.DragMe Parent { get; private set; }

        public Vector3 WorldPosition { get; private set; }

        public TransformData(Vector3 worldPosition, Components.DragMe parent)
        {
            WorldPosition = worldPosition;
            Parent = parent;
        }
    }
}