using Studio.OverOne.DragMe.Data;
using Studio.OverOne.DragMe.Integrations.Abstractions;
using UnityEngine;

namespace Studio.OverOne.DragMe.Data.Abstractions 
{
    public interface IDragMeConfig 
    {
        #region " Dependencies "

        IInputSource InputSource { get; }

        Camera Camera { get; }

        #endregion

        #region " Configuration "

        bool FixedUpdate { get; set; }

        CollisionType CollisionType { get; set; }

        DragType DragType { get; set; }

        Orientation Orientation { get; set; }

        LayerMask GrabMask { get; set; }

        LayerMask PlacementMask { get; set; }

        float MaxDistance { get; set; }

        QueryTriggerInteraction TriggerInteraction { get; set; }

        int DragHistoryMaxLength { get; set; }

        #endregion

        #region " Behavior "

        bool HideMouseOnDrag { get; set; }

        float DistanceThreshold { get; set; }

        #endregion
    }
}