using UnityEngine;

namespace Studio.OverOne.DragMe.Data.Abstractions
{
    public interface IResetEventData 
    {
        Components.DragMe ResetComponent { get; }

        Vector3 MousePosition { get; }
    }
}