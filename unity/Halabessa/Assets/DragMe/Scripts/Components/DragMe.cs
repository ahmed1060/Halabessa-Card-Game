using Studio.OverOne.DragMe.Components.Abstractions;
using Studio.OverOne.DragMe.Data;
using Studio.OverOne.DragMe.Data.Abstractions;
using Studio.OverOne.DragMe.Data.Events;
using Studio.OverOne.DragMe.Extensions;
using Studio.OverOne.DragMe.Integrations.Abstractions;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.Assertions;

namespace Studio.OverOne.DragMe.Components 
{
    // * Partial class containing the core of Drag Me drag & drop functionality.
    public sealed partial class DragMe : MonoBehaviour
        , IDragMe
    {
        #region " Internal Variables "

        // Contains a reference to all DragMe components. 
        private static readonly List<Components.DragMe> _components = new List<DragMe>(); 

        // DraggedEventData collected from the last time the DragMe component was dragged, empty otherwise.
        private readonly List<IDraggedEventData> _draggedHistory = new List<IDraggedEventData>();

        // Reference to the place that will be used when dragging.
        private Plane _dragPlane;
        
        // Reference to the Rigidbody component.
        // NOTE: Using the Rigidbody component on our gameObject registers the child
        //  colliders with the physics system so we can build our prefab models 
        //  seperate from the controlling parent.
        private Rigidbody _rigidbody;

        // Reference to the Rigidbody2d component.
        private Rigidbody2D _rigidbody2d;

        // TransformData collection containing the Parent and Transform information of the DragMe component.
        private readonly List<ITransformData> _transformHistory = new List<ITransformData>();

        #endregion

        #region " Unity Methods "

        private void Awake()
        {
            Assert.IsNotNull(Config, Errors.IsNull.Fmt(nameof(Config)));
            DragMeConfig.Init(Config);

            if(Config.CollisionType == CollisionType.Physics2D)
            {
                _rigidbody2d = GetComponent<Rigidbody2D>();
                Assert.IsNotNull(_rigidbody2d, Errors.IsNull.Fmt(nameof(_rigidbody2d)));
            }
            else 
            {
                _rigidbody = GetComponent<Rigidbody>();
                Assert.IsNotNull(_rigidbody, Errors.IsNull.Fmt(nameof(Rigidbody)));
            }
        }

        private void Start()
        {
            RegisterEventListeners();

            // Add ourselves to the DragMe.Components collection.
            if(!_components.Contains(this))
                _components.Add(this);

            _desiredPosition = WorldPosition;

            // Add our starting parent and position.
            _transformHistory.Add(new TransformData(
                WorldPosition,
                MyParentDragMeComponent));
        }

        private void OnDestroy()
        {
            ClearEventListeners();

            // Remove ourselves from the DragMe.Components collection.
            _components.Remove(this);
        }

        private void Reset()
        {
            Init();
        }

        private void FixedUpdate()
        {
            if(Config.FixedUpdate)
                UpdateMyself(Input.mousePosition);
        }

        private void Update()
        {
            if(!Config.FixedUpdate)
                UpdateMyself(Input.mousePosition);

            UpdatePosition(Time.fixedDeltaTime);

            OrderChildrenAndApplyOffset();
        }

        #endregion

        #region " Utility Methods "

        private void RegisterEventListeners()
        {
            // Empty.
        }

        private void ClearEventListeners()
        {
            e_Selected.RemoveAllListeners();
            e_Deselected.RemoveAllListeners();
            e_Grabbed.RemoveAllListeners();
            e_Dragged.RemoveAllListeners();
            e_Released.RemoveAllListeners();
            e_Placed.RemoveAllListeners();
            e_Blocked.RemoveAllListeners();
        }

        private void Init()
        {
             OrderChildrenAndApplyOffset();
        }

        private void CreateDragPlane()
        {
            Vector3 lNormal;

            switch(Config.Orientation)
            {
                case Orientation.XY: lNormal = Vector3.back; break;
                case Orientation.XZ: lNormal = Vector3.up; break;
                case Orientation.YZ: lNormal = Vector3.right; break;
                case Orientation.YX: lNormal = Vector3.forward; break;
                case Orientation.ZX: lNormal = Vector3.down; break;
                case Orientation.ZY: lNormal = Vector3.left; break;
                case Orientation.Camera: lNormal = -Config.Camera.transform.forward; break;

                default: lNormal = Vector3.up; break;
            }
            
            _dragPlane = new Plane(lNormal, transform.position);
        }

        private void UpdatePosition(float fixedDeltaTime)
        {
            float lDistanceApart = Vector3.SqrMagnitude(WorldPosition - _desiredPosition);

            // ? Is the grabbed gameObject too far away ...
            if(lDistanceApart < Config.DistanceThreshold)
                return;

            DraggedTime = Time.time;

            Vector3 lDirection = (WorldPosition - _desiredPosition)
                .normalized;

            WorldPosition = WorldPosition + lDirection * fixedDeltaTime;
        }

        private void Disable3dColliders(ref List<Collider> colliders, bool includeSelf = true)
        {
            if(Config.CollisionType == CollisionType.Physics2D)
                return; 

            colliders = colliders ?? new List<Collider>();

            Components.DragMe[] lComponents = MyDragMeComponents 
                ?? new Components.DragMe[0];

            if(lComponents.Length == 0)
                return;

            // for(int i = 0; i < lComponents.Count; i++)
            //     if(lComponents[i] != this)
            //         lComponents[i].DisableColliders(ref colliders, false);

            // ? Using 'GetComponentInChildren<Collider>() is my preferd approach, however;'
            // ?  Unity appears to not be returning the collider for both this component and
            // ?  its children, but two copies of its child. I even attempted to use some
            // ?  recursion of children, but still encountered the same result.
            // TODO: Find a better solution to getting the necessary colliders. 
            List<Collider> lColliders = lComponents
                .Where(x => includeSelf || x != this)
                //.Select(x => x.GetComponentInChildren<Collider>())
                .SelectMany(x => x.GetComponentsInChildren<Collider>())
                .Where(x => x != null && x.enabled)
                .Distinct().ToList();

            for(int i = 0; i < lColliders.Count; i++)
                lColliders[i].enabled = false;

            colliders.AddRange(lColliders);
        }

        private void Disable2dColliders(ref List<Collider2D> colliders, bool includeSelf = true)
        {
            if(Config.CollisionType == CollisionType.Physics3D)
                return;

            colliders = colliders ?? new List<Collider2D>();

            Components.DragMe[] lComponents = MyDragMeComponents 
                ?? new Components.DragMe[0];

            if(lComponents.Length == 0)
                return;
            
            // TODO: Find a better solution to getting the necessary colliders. 
            List<Collider2D> lColliders = lComponents
                .Where(x => includeSelf || x != this)
                .SelectMany(x => x.GetComponentsInChildren<Collider2D>())
                .Where(x => x != null && x.enabled)
                .Distinct().ToList();

            for(int i = 0; i < lColliders.Count; i++)
                lColliders[i].enabled = false;

            colliders.AddRange(lColliders);
        }

        private static void Enable3dColliders(ref List<Collider> colliders)
        {
            if(colliders == null)
                return;

            for(int i = 0; i < colliders.Count; i++)
                colliders[i].enabled = true;
        }

        private static void Enable2dColliders(ref List<Collider2D> colliders)
        {
            if(colliders == null)
                return; 

            for(int i = 0; i < colliders.Count; i++)
                colliders[i].enabled = true;
        }

        private void OrderChildrenAndApplyOffset()
        {
            IList<Components.DragMe> lChildren = MyChildDragMeComponents;

            if(lChildren.Count == 0)
                return;

            Transform[] lTransforms = GetComponentsInChildren<Transform>();
            int lNonDragMeChildren = Mathf.Abs(lChildren.Count - lTransforms.Length);

            for(int i = 0; i < lChildren.Count; i++)
            {
                float lZ = lChildren[i].transform.position.z;

                // * Set the parent.
                lChildren[i].transform.SetParent(transform);

                // * Normalize the position relative to the parent.
                lChildren[i].transform.localPosition = Vector3.zero;

                // * Set sibling index.
                lChildren[i].transform.SetSiblingIndex(i + lNonDragMeChildren);

                // * Apply offset
                int lOffset = ApplyOffsetToFirstChild ? i + 1 : i;
                lChildren[i].transform.localPosition += ChildOffset * lOffset;

                if(Config.CollisionType == CollisionType.Physics2D)
                {
                    Vector3 lPosition = lChildren[i].transform.localPosition;
                    lChildren[i].transform.localPosition 
                        = new Vector3(lPosition.x, lPosition.y, lZ);
                }
            }
        }

        private bool TryAddToHistory(Vector3 mousePosition, out IDraggedEventData eventData)
        {
            // ? Do we already have a movement history ...
            IDraggedEventData lPrevData = null;
            if(_draggedHistory.Count > 0)
            {
                // ? ... Yes, grab the latest history entry so it can be used when creating our 
                // ?  new entry.
                int lPrevDataIndex = _draggedHistory.Count - 1;
                lPrevData = _draggedHistory[lPrevDataIndex];
            }

            eventData = AddToHistory(mousePosition, lPrevData);

            return true;
        }

        private IDraggedEventData AddToHistory(Vector3 location, IDraggedEventData prevData)
        {
            IDraggedEventData lCurrData  = new DraggedEventData(prevData?.CurrentMousePosition ?? location, location, this);
            _draggedHistory.Add(lCurrData);

            int lRemoveCount = _draggedHistory.Count - Config.DragHistoryMaxLength;
            if(lRemoveCount > 0)
                _draggedHistory.RemoveRange(0, lRemoveCount);

            return lCurrData;
        }

        bool TryGetDragMeComponentFromPhysics2d(Vector3 mousePosition, LayerMask layerMask, out Components.DragMe comp)
        {
            Ray lSelectRay = Config.Camera.ScreenPointToRay(mousePosition);
            RaycastHit2D lHit = Physics2D.Raycast(lSelectRay.origin, lSelectRay.direction, Config.MaxDistance, layerMask);

            comp = lHit.collider
                ?.GetComponentInParent<Components.DragMe>();

            return comp != null;
        }

        bool TryGetDragMeComponentFromPhysics(Vector3 mousePosition, LayerMask layerMask, out Components.DragMe comp)
        {
            Ray lSelectRay = Config.Camera.ScreenPointToRay(mousePosition);
            
            bool lFound = Physics.Raycast(lSelectRay, out var lSelectedHit3d, Config.MaxDistance, layerMask, Config.TriggerInteraction);
            comp = lSelectedHit3d.collider
                ?.GetComponentInParent<Components.DragMe>();

                return lFound;
        }

        #endregion
    
        #region " Debug Methods "

        private void RenderDragPlane()
        {
            Vector3 normal = _dragPlane.normal;
            Vector3 lPosition = WorldPosition + _dragPlane.normal + DebugDrawOffset;

            Vector3 v3;
 
            if (normal.normalized != Vector3.forward)
                v3 = Vector3.Cross(normal, Vector3.forward).normalized * normal.magnitude;
            else
                v3 = Vector3.Cross(normal, Vector3.up).normalized * normal.magnitude;;
                
            var corner0 = lPosition + v3;
            var corner2 = lPosition - v3;
            var q = Quaternion.AngleAxis(90.0f, normal);
            v3 = q * v3;
            var corner1 = lPosition + v3;
            var corner3 = lPosition - v3;
            
            Debug.DrawLine(corner0, corner2, Color.green);
            Debug.DrawLine(corner1, corner3, Color.green);
            Debug.DrawLine(corner0, corner1, Color.green);
            Debug.DrawLine(corner1, corner2, Color.green);
            Debug.DrawLine(corner2, corner3, Color.green);
            Debug.DrawLine(corner3, corner0, Color.green);
            Debug.DrawRay(lPosition, normal, Color.red);
        }

        #endregion 

        #region " Internal Methods "

        private bool UpdateMyself(Vector3 mousePosition)
        {
            IInputSource lInputSource = Config.InputSource;

            // Are we selected ...
            Components.DragMe lSelectedInstance = null;
            bool lSelectionFound = Config.CollisionType == CollisionType.Physics2D
                ? TryGetDragMeComponentFromPhysics2d(mousePosition, Config.GrabMask, out lSelectedInstance)
                : TryGetDragMeComponentFromPhysics(mousePosition, Config.GrabMask, out lSelectedInstance);

            if(!lSelectionFound || lSelectedInstance != this)
            {
                if(TryDeselect(mousePosition))
                    return false;

                if(lInputSource.Hold && Config.DragType == DragType.Toggle)
                    return TryDrag(mousePosition);
            }

            TrySelect(mousePosition);

            if(Config.DragType == DragType.Hold)
            {
                if(lInputSource.Grab)
                    return TryGrab(mousePosition);
                else if (lInputSource.Release)
                    return TryRelease(mousePosition);
                else if (lInputSource.Hold)
                    TryDrag(mousePosition);
            }
            else if(Config.DragType == DragType.Toggle)
            {
                if(CanGrab && lInputSource.Release)
                    return TryGrab(mousePosition);
                else if (lInputSource.Release)
                    return TryRelease(mousePosition);
                else 
                    TryDrag(mousePosition);
            }

            return true;
        }

        #endregion

        #region " Select Methods "

        public bool TrySelect(Vector3 mousePosition) 
        { 
            if(!CanSelect)
                return false;

            Selected = true;

            ISelectedEventData lData = new SelectedEventData(mousePosition, this);
            e_Selected.Invoke(lData);

            return true;
        }

        #endregion

        #region " Deselect Methods "

        public bool TryDeselect(Vector3 mousePosition) 
        { 
            if(!CanDeselect)
                return false;

            Selected = false;

            IDeselectedEventData lData = new DeselectedEventData(mousePosition, this);
            e_Deselected.Invoke(lData);

            return true;
        }

        #endregion

        #region " Grab Methods "
        
        public bool TryGrab(Vector3 mousePosition) 
        { 
            if(!CanGrab)
                return false;

            int lMyIndex = transform.GetSiblingIndex();
            IList<Components.DragMe> lSiblings = MySiblingDragMeComponents;

            // * Siblings >= my sibling index are 'stacked' on top of me.
            Components.DragMe[] lStack = lSiblings
                .Where(x => x.transform.GetSiblingIndex() >= lMyIndex)
                .ToArray();

            // ! Clear our parent. We must do this first in order for the following TryPlace() to work correctly.
            Parent = null;

            lStack.All(x => TryPlace(mousePosition, x));

            IGrabbedEventData lData = new GrabbedEventData(mousePosition, this);
            e_Grabbed.Invoke(lData);

            return true;
        }

        #endregion

        #region " Release Methods "

        public bool TryRelease(Vector3 mousePosition) 
        { 
            if(!CanRelease)
                return false;

            IReleasedEventData lData = new ReleasedEventData(mousePosition, this);
            e_Released.Invoke(lData);

            return true;
        }

        #endregion

        #region " Place Methods "
        
        public bool TryPlace(Vector3 mousePosition, Components.DragMe comp)
        {
            if(this.transform == comp.transform)
                throw new System.Exception("ERROR: DragMe component tried to place itself on itself.");

            bool? lSuccess = MyParentDragMeComponent?.TryPlace(mousePosition, comp);
            if(lSuccess != null)
                return lSuccess.Value;
            
            if(!Available)
                return false;

            IPlacedEventData lData = new PlacedEventData(mousePosition, comp, this);
            comp.e_Placed.Invoke(lData);

            return true;
        }

        #endregion

        #region " Drag Methods "

        public bool TryDrag(Vector3 mousePosition) 
        { 
            if(!CanDrag)
                return false;

            if(TryAddToHistory(mousePosition, out IDraggedEventData lData))
                e_Dragged.Invoke(lData);

            return true;
        }

        #endregion

        #region " Reset Methods "

        public bool TryResetTransform(Vector3 mousePosition)
        {
            IResetEventData lData = new ResetEventData(mousePosition, this);
            e_Reset.Invoke(lData);

            return true;
        }

        #endregion
    }
}