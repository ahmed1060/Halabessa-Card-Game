#pragma warning disable 0649 // Never assigned to and will always have its default value.

using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

namespace Studio.OverOne.DragMe.Demo
{
    public class DemoController : MonoBehaviour
    {
        #region " Inspector Variables "

        [SerializeField] private List<Components.DragMe> Components = new List<Components.DragMe>();

        [Header("UI Element References")]
        [SerializeField] private Toggle _showDebugRef;

        [SerializeField] private InputField _debugOffsetXRef;
        
        [SerializeField] private InputField _debugOffsetYRef;
        
        [SerializeField] private InputField _debugOffsetZRef;

        [SerializeField] private InputField _minStackRef;

        [SerializeField] private InputField _maxStackRef;

        [SerializeField] private Toggle _applyOffsetToFirstChildRef;

        [SerializeField] private InputField _childOffsetXRef;
        
        [SerializeField] private InputField _childOffsetYRef;
        
        [SerializeField] private InputField _childOffsetZRef;

        #endregion

        private void Start()
        {
            Components.DragMe dm = Components[0];

            _showDebugRef.isOn = dm.ShowDebug;
            
            _debugOffsetXRef.text = dm.DebugDrawOffset.x.ToString();
            _debugOffsetYRef.text = dm.DebugDrawOffset.y.ToString();
            _debugOffsetZRef.text = dm.DebugDrawOffset.z.ToString();
            
            _minStackRef.text = dm.MinStackSize.ToString();
            _maxStackRef.text = dm.MaxStackSize.ToString();

            _applyOffsetToFirstChildRef.isOn = dm.ApplyOffsetToFirstChild;

            _childOffsetXRef.text = dm.ChildOffset.x.ToString();
            _childOffsetYRef.text = dm.ChildOffset.y.ToString();
            _childOffsetZRef.text = dm.ChildOffset.z.ToString();
        }

        public void ShowDebug(bool show)
        {
            Components.ForEach(x => x.ShowDebug = show);
        }

        public void ChangeDebugDrawOffset_X(string value)
        {
            if(!float.TryParse(value, out float lValue))
                return;

            Components.ForEach(x => 
            {
                Vector3 lOffset = new Vector3(lValue, x.DebugDrawOffset.y, x.DebugDrawOffset.z); 
                x.DebugDrawOffset = lOffset;
            });
        }

        public void ChangeDebugDrawOffset_Y(string value)
        {
            if(!float.TryParse(value, out float lValue))
                return;

            Components.ForEach(x => 
            {
                Vector3 lOffset = new Vector3(x.DebugDrawOffset.x, lValue, x.DebugDrawOffset.z); 
                x.DebugDrawOffset = lOffset;
            });
        }

        public void ChangeDebugDrawOffset_Z(string value)
        {
            if(!float.TryParse(value, out float lValue))
                return;

            Components.ForEach(x => 
            {
                Vector3 lOffset = new Vector3(x.DebugDrawOffset.x, x.DebugDrawOffset.y, lValue); 
                x.DebugDrawOffset = lOffset;
            });
        }

        public void ChangeChildOffset_X(string value)
        {
            if(!float.TryParse(value, out float lValue))
                return;

            Components.ForEach(x => 
            {
                Vector3 lOffset = new Vector3(lValue, x.DebugDrawOffset.y, x.DebugDrawOffset.z); 
                x.ChildOffset = lOffset;
            });
        }

        public void ChangeChildOffset_Y(string value)
        {
            if(!float.TryParse(value, out float lValue))
                return;

            Components.ForEach(x => 
            {
                Vector3 lOffset = new Vector3(x.DebugDrawOffset.x, lValue, x.DebugDrawOffset.z); 
                x.ChildOffset = lOffset;
            });
        }

        public void ChangeChildOffset_Z(string value)
        {
            if(!float.TryParse(value, out float lValue))
                return;

            Components.ForEach(x => 
            {
                Vector3 lOffset = new Vector3(x.DebugDrawOffset.x, x.DebugDrawOffset.y, lValue); 
                x.ChildOffset = lOffset;
            });
        }

        public void ChangeMinStackSize(string value)
        {
            if(!int.TryParse(value, out int lValue))
                return;

            Components.ForEach(x => x.MinStackSize = lValue);
        }

        public void ChangeMaxStackSize(string value)
        {
            if(!int.TryParse(value, out int lValue))
                return;

            Components.ForEach(x => x.MaxStackSize = lValue);
        }

        public void ApplyOffsetToFirstChild(bool value)
        {
            Components.ForEach(x => x.ApplyOffsetToFirstChild = value);
        }
    }
}