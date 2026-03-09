using Studio.OverOne.DragMe.Data;
using Studio.OverOne.DragMe.Data.Abstractions;
using Studio.OverOne.DragMe.Events;
using System.Collections.Generic;
using UnityEngine;

namespace Studio.OverOne.DragMe.Components.Abstractions 
{
    public interface IDragMe 
    {
        DragMeConfig Config { get; set; }

        Components.DragMe[] MyDragMeComponents { get; }

        Components.DragMe[] MyChildDragMeComponents { get; }

        Components.DragMe MyParentDragMeComponent { get; }

        Components.DragMe[] MySiblingDragMeComponents { get; }

        Components.DragMe[] MySeniorDragMeComponents { get; }

        Transform Parent { get; }

        Vector3 WorldPosition { get; }

        #region " Events "

        SelectedEvent e_Selected { get; }

        GrabbedEvent e_Grabbed { get; }

        DraggedEvent e_Dragged { get; }

        DeselectedEvent e_Deselected { get; }

        PlacedEvent e_Placed { get; }

        BlockedEvent e_Blocked { get; }

        ReleasedEvent e_Released { get; }

        ResetEvent e_Reset { get; }

        #endregion

        bool CanSelect { get; }

        bool CanDeselect { get; }

        bool CanGrab { get; }

        bool CanDrag { get; }

        bool CanRelease { get; }

        bool Held { get; }

        bool Placed { get; }

        bool Selected { get; }

        bool Grabbed { get; }

        #region " Debug "

        bool ShowDebug { get; set; }

        Vector3 DebugDrawOffset { get; set; }

        #endregion

        #region " Timer "

        float GrabTimer { get; }

        float SelectedTime { get; }

        float DeselectedTime { get; }

        float GrabbedTime { get; }

        float DraggedTime { get; }

        float ReleasedTime { get; }

        float PlacedTime { get; }

        float BlockedTime { get; }

        #endregion

        #region " Behavior "

        Vector3 DesiredPosition { get; set; }

        int MinStackSize { get; set; }

        int MaxStackSize { get; set; }

        bool ApplyOffsetToFirstChild { get; set; }

        Vector3 ChildOffset { get; set; }

        #endregion
    }
}