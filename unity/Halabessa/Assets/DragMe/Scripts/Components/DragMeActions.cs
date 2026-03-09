using Studio.OverOne.DragMe.Data;
using Studio.OverOne.DragMe.Data.Abstractions;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;

namespace Studio.OverOne.DragMe.Components 
{
    // * A DragMe partial class containing event methods used by the Drag Me core.
    //  These methods are wired to the events within the Unity inspector to control component behavior.
    //  Adding or removing these events within the Unity inspector will add/remove functionality 
    //  of the DragMe component.
    public sealed partial class DragMe : MonoBehaviour
    {
        #region " Public Methods "

        // * Grabs the DragMe component and creates a dragPlane.
        public void GrabMe(IGrabbedEventData eventData)
        {
            if(eventData.GrabbedComponent != this)
                return;

            Grabbed = true;

            CreateDragPlane();
        }

        // * Moves the DragMe component with the mouse across the dragPlane.
        public void MoveMe(IDraggedEventData eventData)
        {
            if(eventData.DraggedComponent != this)
                return;

            Ray lRay = Config.Camera.ScreenPointToRay(eventData.CurrentMousePosition);
            _dragPlane.Raycast(lRay, out var lDistanceAway);

            DesiredPosition = lRay.GetPoint(lDistanceAway);

            int i = -1;
            while (++i < MyDragMeComponents.Length)
                MyDragMeComponents[i].GrabTimer = Time.time + Config.DebounceTime;
        }

        // * Places the DragMe component onto another DragMe component by setting the parent.
        public void PlaceMe(IPlacedEventData eventData)
        {
            if(eventData.PlacedComponent != this)
                return; 
            
            Parent = eventData.PlacementComponent
                .transform;
        }

        // * Releases the DragMe component and attempts to find another DragMe component to try and place it on.
        public void ReleaseMe(IReleasedEventData eventData)
        {
            if(eventData.ReleasedComponent != this)
                return;
            
            if(Config.HideMouseOnDrag)
                Cursor.visible = true;

            Grabbed = false;

            // * Disable any enabled colliders so they do not interfere with our raycast.
            List<Collider2D> l2dColliders = null;
            List<Collider> l3dColliders = null;
            Disable2dColliders(ref l2dColliders);
            Disable3dColliders(ref l3dColliders);

            Vector3 lMousePosition = eventData.MousePosition;
            Components.DragMe lPlacementInstance = null;
            bool lPlacementFound = Config.CollisionType == CollisionType.Physics2D
                ? TryGetDragMeComponentFromPhysics2d(lMousePosition, Config.PlacementMask, out lPlacementInstance)
                : TryGetDragMeComponentFromPhysics(lMousePosition, Config.PlacementMask, out lPlacementInstance);

            // * Enable any previously disabled colliders.
            Enable2dColliders(ref l2dColliders);
            Enable3dColliders(ref l3dColliders);

            if(!lPlacementFound || lPlacementInstance == this)
            {
                TryResetTransform(lMousePosition);
                return;
            }
            
            // this: Component we want to place.
            // lPlacementInstance: Component we want to place this onto.
            if(lPlacementInstance.TryPlace(lMousePosition, this))
                return;

            // * Placement failed.
            TryResetTransform(lMousePosition);
        }

        // * Iterates through all sibling DragMe components and initiates a call to their TryResetTransform(...).
        public void ResetSiblings(IPlacedEventData eventData)
        {
            if(eventData.PlacedComponent != this)
                return; 

            foreach(Components.DragMe lSibling in MySiblingDragMeComponents)
                lSibling.TryResetTransform(eventData.MousePosition);
        }

        // * Resets this DragMe component to it's starting parent and or position.
        public void ResetToStart(IResetEventData eventData)
        {
            if(eventData.ResetComponent != this)
                return;

            ITransformData lStart = _transformHistory[0];
            
            Parent = lStart.Parent?.transform;
            DesiredPosition = lStart.WorldPosition;
        }

        #endregion
    }
}