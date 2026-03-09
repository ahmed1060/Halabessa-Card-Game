#pragma warning disable 0649 // Never assigned to and will always have its default value.

using Studio.OverOne.DragMe.Data.Abstractions;
using Studio.OverOne.DragMe.Extensions;
using Studio.OverOne.DragMe.Integrations.Abstractions;
using UnityEngine;
using UnityEngine.Assertions;

namespace Studio.OverOne.DragMe.Data
{
    [System.Serializable]
    [CreateAssetMenu(fileName = "DragMeConfig", menuName = "Drag Me/Config")]
    public sealed partial class DragMeConfig : ScriptableObject
        , IDragMeConfig
    {
        public IInputSource InputSource { get; private set; }

        #region " Dependency Inspector Variables "

        [Header("Dependencies"), Tooltip("The InputSource that will be used by the DragMe components.")]
        [SerializeField] private InputSourceBase _inputSourcePrefab;
        
        public Camera Camera { get => _camera; private set => _camera = value; }

        [Tooltip("The camera that will be used by DragMe. If not set, Camera.main will be used.")]
        [SerializeField] private Camera _camera;

        #endregion

        #region " Configuration Inspector Variables "
        
        public bool FixedUpdate { get => _fixedUpdate; set => _fixedUpdate = value; }

        [Header("Configuration"), Tooltip("True if DragMe components will update during FixedUpdate(), false if DragMe components should update during Update() instead.")]
        [SerializeField] private bool _fixedUpdate;
        
        public CollisionType CollisionType { get => _collisionType; set => _collisionType = value; }

        [Tooltip("Indicates whether DragMe will use the 2D or 3D physics system.")]
        [SerializeField] private CollisionType _collisionType;

        public DragType DragType { get => _dragType; set => _dragType = value; }

        [Tooltip("Indicates the behavior used when grabbing and dragging an object.")]
        [SerializeField] private DragType _dragType;
        
        public Orientation Orientation { get => _orientation; set => _orientation = value; }

        [Tooltip("The orientation in which the DragPlane is created, allowing DragMe components to be moved.")]
        [SerializeField] private Orientation _orientation = Orientation.Camera;
        
        public LayerMask GrabMask { get => _grabMask; set => _grabMask = value;}

        [Tooltip("The LayerMask containing objects that can be grabbed.")]
        [SerializeField] private LayerMask _grabMask = 0;
        
        public LayerMask PlacementMask { get => _placementMask; set => _placementMask = value; }

        [Tooltip("The LayerMask containing objects that allow a grabbed object to be placed.")]
        [SerializeField] private LayerMask _placementMask = 0;
        
        public float MaxDistance { get => _maxDistance; set => _maxDistance = value; }

        [Tooltip("The maximum distance from the Main Camera that an object can be grabbed.")]
        [SerializeField] private float _maxDistance = 100f;
        
        public QueryTriggerInteraction TriggerInteraction { get => _triggerInteraction; set => _triggerInteraction = value; }

        [Tooltip("The QueryTriggerInteraction used when a 'Trigger' collider is encountered.")]
        [SerializeField] private QueryTriggerInteraction _triggerInteraction = QueryTriggerInteraction.Collide;
        
        public int DragHistoryMaxLength { get => _dragHistoryMaxLength; set => _dragHistoryMaxLength = value; }

        [Tooltip("The number of DraggedEventData entries retained when dragging a DragMe component.")]
        [SerializeField] private int _dragHistoryMaxLength = 5;

        public int TransformHistoryMaxLength { get => _transformHistoryMaxLength; set => _transformHistoryMaxLength = value; }

        [Tooltip("The number of TransformHistory entries retained whenswitching the parent of a DragMe component.")]
        [SerializeField] private int _transformHistoryMaxLength = 5;

        #endregion

        #region " Behaviour Inspector Variables "
        
        public bool HideMouseOnDrag { get => _hideMouseOnDrag; set => _hideMouseOnDrag = value; }

        [Tooltip("True if the mouse cursor should be hidden when dragging a DragMe component, false otherwie.")]
        [SerializeField] private bool _hideMouseOnDrag;
        
        public float DebounceTime { get => _debounceTime; set => _debounceTime = value;}

        [Min(1f), Tooltip("Time in seconds taken for a Components.DragMe component to be grabbed after being released.")]
        [SerializeField] private float _debounceTime = 0.25f;
        
        public float DistanceThreshold { get => _distanceThreshold; set => _distanceThreshold = value; }

        [Tooltip("The distance in meters a DragMe component must move before updating it's position and adding a DraggedEventData entry. ")]
        [SerializeField] private float _distanceThreshold;

        #endregion

        #region " Create & Init Methods "

        public static DragMeConfig Create(string resourceName)
        {
            DragMeConfig lConfig = Resources.Load<DragMeConfig>(resourceName);
            return Create(lConfig);
        }

        public static DragMeConfig Create(DragMeConfig config)
        {
            DragMeConfig lConfig = CreateInstance<DragMeConfig>();

            if(config != null)
            {
                lConfig._inputSourcePrefab = config._inputSourcePrefab;
                lConfig.Camera = config.Camera;
                lConfig.Orientation = config.Orientation;
                lConfig.DebounceTime = config.DebounceTime;
                lConfig.DragType = config.DragType;
                lConfig.MaxDistance = config.MaxDistance;
                lConfig.GrabMask = config.GrabMask;
                lConfig.PlacementMask = config.PlacementMask;
                lConfig.TriggerInteraction = config.TriggerInteraction;
                lConfig.DragHistoryMaxLength = config.DragHistoryMaxLength;
                lConfig.DistanceThreshold = config.DistanceThreshold;
                lConfig.HideMouseOnDrag = config.HideMouseOnDrag;
            }

            if(lConfig.GrabMask == 0)
                lConfig.GrabMask = LayerMask.NameToLayer("Everything");

            if(lConfig.PlacementMask == 0)
                lConfig.PlacementMask = LayerMask.NameToLayer("Everything");

            Init(lConfig);

            return lConfig;
        }

        public static void Init(DragMeConfig config)
        {
            Assert.IsNotNull(config._inputSourcePrefab, Errors.IsNull.Fmt(nameof(config._inputSourcePrefab)));

            InputSourceBase lInputSource = FindObjectOfType<InputSourceBase>();

            if(lInputSource == null)
            {
                lInputSource = Instantiate(config._inputSourcePrefab, Vector3.zero, Quaternion.identity);
                lInputSource.name = "Input Source";
            }

            config.InputSource = lInputSource;
            Assert.IsNotNull(config.InputSource, Errors.IsNull.Fmt(nameof(InputSource)));

            if(config.Camera == null)
                config.Camera = Camera.main;
            Assert.IsNotNull(config.Camera, Errors.IsNull.Fmt(nameof(Camera)));
        }
    
        #endregion
    }
}