#pragma warning disable 0649 // Never assigned to and will always have its default value.

using Studio.OverOne.DragMe.Components.Abstractions;
using Studio.OverOne.DragMe.Data;
using Studio.OverOne.DragMe.Data.Abstractions;
using Studio.OverOne.DragMe.Events;
using System.Linq;
using UnityEngine;

namespace Studio.OverOne.DragMe.Components
{
    // * A DragMe partial class containing all fields and properties used by the Drag Me core.
    public sealed partial class DragMe : MonoBehaviour
        , IDragMe
    {
        // Returns the parent of the DragMe transform.
        public Transform Parent
        {
            get => MyParentDragMeComponent?.transform;
            set
            {
                if(transform.parent != value)
                {
                    ITransformData lData = new TransformData(WorldPosition, MyParentDragMeComponent);
                    _transformHistory.Add(lData);
                }
                
                transform.SetParent(value?.transform);
                DesiredPosition = value?.GetComponent<Components.DragMe>()
                    .WorldPosition ?? DesiredPosition;
            }
        }

        // Returns the position of the attached Rigidbody.
        public Vector3 WorldPosition
        {
            get => _rigidbody?.position ?? new Vector3(_rigidbody2d.position.x, _rigidbody2d.position.y, transform.position.z);
            private set 
            {
                _rigidbody?.MovePosition(_desiredPosition); 
                _rigidbody2d?.MovePosition(new Vector3(_desiredPosition.x, _desiredPosition.y, transform.position.z));
            }
        }

        // Returns a collection of DragMe components containing myself and my children.
        public Components.DragMe[] MyDragMeComponents => 
            GetComponentsInChildren<Components.DragMe>()
            .ToArray() ?? new Components.DragMe[0];

        // Returns a collection of DragMe components containing my children.
        public Components.DragMe[] MyChildDragMeComponents => 
            GetComponentsInChildren<Components.DragMe>()
            .Where(x => x != this)
            .ToArray() ?? new Components.DragMe[0];

        // Returns a collection of DragMe components containing my siblings.
        public Components.DragMe[] MySiblingDragMeComponents => 
            MyParentDragMeComponent?.MyChildDragMeComponents
            .Where(x => x != this)
            .ToArray() ?? new Components.DragMe[0];

        public Components.DragMe MyParentDragMeComponent => 
            transform.parent?.GetComponent<Components.DragMe>();

        // Returns a collection of DragMe components containing my seniors.
        public Components.DragMe[] MySeniorDragMeComponents => 
            GetComponentsInParent<Components.DragMe>()
            .ToArray() ?? new Components.DragMe[0];

        // Returns true if this DragMe component can be selected, false otherwise.
        public bool CanSelect => !Selected && !Grabbed 
            && ParentMinStackSizeExceeded
            && !MaxStackSizeExceeded
            && Time.time > GrabTimer;

        // Returns true if this DragMe component can be deselected, false otherwise.
        public bool CanDeselect => !Grabbed;

        // Returns true if this DragMe component can be grabbed, false otherwise.
        public bool CanGrab => !Held 
            && Selected && !Grabbed
            && ParentMinStackSizeExceeded
            && !MaxStackSizeExceeded
            && Time.time > GrabTimer;
        
        public bool ParentMinStackSizeExceeded => MyParentDragMeComponent == null 
            || MyParentDragMeComponent.MinStackSize == 0
            || MyParentDragMeComponent.MyChildDragMeComponents.Length 
                - (MySiblingDragMeComponents.Length - transform.GetSiblingIndex() 
                + Mathf.Abs(MyParentDragMeComponent.MyChildDragMeComponents.Length 
                - GetComponentsInChildren<Transform>().Length)) >= MyParentDragMeComponent.MinStackSize;

        public bool MaxStackSizeExceeded =>
            MySiblingDragMeComponents
            .Where(x => x.transform.GetSiblingIndex() > transform.GetSiblingIndex())
            .Count() > MaxStackSize;

        // Returns true if this DragMe component can be dragged, false otherwise.
        public bool CanDrag => Selected && Grabbed;

        public bool CanRelease => Grabbed;

        // Returns true if this component is held, false otherwise.
        public bool Held => MySeniorDragMeComponents.Any(x => x.Grabbed);

        // True if this DragMe component has been placed, false otherwise.
        public bool Placed
        {
            get => MyParentDragMeComponent != null;
            private set => PlacedTime = value ? Time.time : PlacedTime; 
        }
        
        public bool Available => 
            MyChildDragMeComponents.Length < MaxStackSize;

        // True if this DragMe component is selected, false otherwise.
        public bool Selected
        {
            get => _selected;
            private set 
            {
                if(value == true)
                    SelectedTime = Time.time;
                else 
                    DeselectedTime = Time.time;

                _selected = value;
            }
        }
        
        private bool _selected;

        // True if this DragMe component is Grabbed, false otherwise.
        public bool Grabbed
        {
            get => _grabbed;
            private set 
            {
                if(value == true)
                    GrabbedTime = Time.time;
                else 
                {
                    ReleasedTime = Time.time;
                    GrabTimer = Time.time + Config.DebounceTime;
                }

                _grabbed = value;
            }
        }
        
        private bool _grabbed;

        #region " Configuration Inspector Variables "

        public DragMeConfig Config { get => _config; set => _config = value; }

        [Header("Configuration"), Tooltip("Config used to configure the behaviour of this component. If null, a default asset will be loaded.")]
        [SerializeField] private DragMeConfig _config = null;

        #endregion

        #region " Behavior Inspector Variables "
        
        public Vector3 DesiredPosition { get => _desiredPosition; set => _desiredPosition = value; } 

        [Header("Position"), Tooltip("WorldPosition the DraMe component wants to move to.")]
        [SerializeField] private Vector3 _desiredPosition;

        public int MinStackSize { get => _minStackSize; set => _minStackSize = value; }

        [Header("Stack"), Tooltip("Indicates the minimum number of cards that can be on this stack before selection and grabbing is disabled.")]
        [Min(0), SerializeField] private int _minStackSize;
        
        public int MaxStackSize { get => _maxStackSize; set => _maxStackSize = value; }

        [Tooltip("Indicates the maximum number of cards that can be added to this stack.")]
        [SerializeField] private int _maxStackSize = int.MaxValue;
        
        public bool ApplyOffsetToFirstChild { get => _applyOffsetToFirstChild; set => _applyOffsetToFirstChild= value; }

        [Header("Children"), Tooltip("True if the first child of this component should have the offset applied, false otherwise.")]
        [SerializeField] private bool _applyOffsetToFirstChild;
        
        public Vector3 ChildOffset { get => _childOffset; set => _childOffset = value; }

        [Tooltip("Offset to apply to DragMe objects when multiple are placed here.")]
        [SerializeField] private Vector3 _childOffset  = Vector3.zero;

        #endregion

        #region " Events "
        
        public SelectedEvent e_Selected { get => _onSelected; }

        [Header("Events"), Tooltip("Called when he DragMe component is selected.")]
        [SerializeField] private SelectedEvent _onSelected = new SelectedEvent();
        
        [Tooltip("Called when the DragMe component is deselected.")]
        [SerializeField] private DeselectedEvent _onDeselected = new DeselectedEvent(); 

        public DeselectedEvent e_Deselected { get => _onDeselected; }

        public GrabbedEvent e_Grabbed { get => _onGrabbed; }

        [Tooltip("Called when the DragMe component is Grabbed.")]
        [SerializeField] private GrabbedEvent _onGrabbed = new GrabbedEvent();
        
        public DraggedEvent e_Dragged { get => _onDragged; }

        [Tooltip("Called when the DragMe component is dragged.")]
        [SerializeField] private DraggedEvent _onDragged = new DraggedEvent();

        public ReleasedEvent e_Released { get => _onReleased; }

        [Tooltip("Called when the DragMe component is released.")]
        [SerializeField] private ReleasedEvent _onReleased = new ReleasedEvent();
        
        public PlacedEvent e_Placed { get => _onPlaced; }

        [Tooltip("Called when the DragMe component is placed.")]
        [SerializeField] private PlacedEvent _onPlaced  = new PlacedEvent();
        
        public BlockedEvent e_Blocked { get => _onBlocked; }

        [Tooltip("Called when the DragMe component is blocked from being placed.")]
        [SerializeField] private BlockedEvent _onBlocked  = new BlockedEvent();
        
        public ResetEvent e_Reset { get => _onReset; }

        [Tooltip("Called when the DragMe component is reset.")]
        [SerializeField] private ResetEvent _onReset = new ResetEvent();

        #endregion
    
        #region " Debug Inspector Variables "
        
        public bool ShowDebug { get => _showDebug; set { _showDebug = value; }}

        [Header("Debug"), Tooltip("True to render the dragPlane and dragPlane normal within the inspector when the DragMe component is grabbed, false otherwise.")] 
        [SerializeField] private bool _showDebug = true;
        
        public Vector3 DebugDrawOffset { get => _debugDrawOffset; set => _debugDrawOffset = value; }

        [Tooltip("Offset used to move the rendered debug dragPlane away from the grabbed objects transform.")]
        [SerializeField] private Vector3 _debugDrawOffset = new Vector3(0f, 0.25f, 0f);

        #endregion
        
        #region " Time Inspector Variables "
        
        public float GrabTimer { get => _grabTimer; private set => _grabTimer = value; }

        [Header("Time [internal]"), Tooltip("Used to debounce the selection and grabbing of a previously grabbed component.")]
        [SerializeField] private float _grabTimer = float.NegativeInfinity;

        public float SelectedTime  { get => _selectedTime; private set => _selectedTime = value; }

        [Tooltip("Time in seconds since the DragMe component was selected.")]
        [SerializeField] private float _selectedTime = float.NegativeInfinity;
        
        public float DeselectedTime { get => _deselectedTime; private set => _deselectedTime = value; }

        [Tooltip("Time in seconds since the DragMe component was deselected.")]
        [SerializeField] private float _deselectedTime = float.NegativeInfinity;
        
        public float GrabbedTime { get => _grabbedTime; private set => _grabbedTime = value; }

        [Tooltip("Time in seconds since the DragMe component was grabbed.")]
        [SerializeField] private float _grabbedTime = float.NegativeInfinity;
        
        public float DraggedTime { get => _draggedTime; private set => _draggedTime = value; }

        [Tooltip("Time in seconds since the DragMe component was dragged.")]
        [SerializeField] private float _draggedTime = float.NegativeInfinity;
        
        public float ReleasedTime { get => _releasedTime; private set => _releasedTime = value; }

        [Tooltip("Time in seconds since the DragMe component was released.")]
        [SerializeField] private float _releasedTime = float.NegativeInfinity;
        
        public float PlacedTime { get => _placedTime; private set => _placedTime = value; }

        [Tooltip("Time in seconds since the DragMe component was placed.")]
        [SerializeField] private float _placedTime = float.NegativeInfinity;
        
        public float BlockedTime { get => _blockedTime; private set => _blockedTime = value; }

        [Tooltip("Time in seconds since the DragMe component was blocked.")]
        [SerializeField] private float _blockedTime = float.NegativeInfinity;

        #endregion

    }
}