using Studio.OverOne.DragMe.Data;
using Studio.OverOne.DragMe.Data.Abstractions;
using UnityEditor;
using UnityEngine; 
using UnityEngine.Events;

namespace Studio.OverOne.DragMe.Editor
{
    public static class Actions
    {
        private const string BASE_PATH_2D = "GameObject/2D Object/";

        private const string BASE_PATH_3D = "GameObject/3D Object/";

        private static bool TryCreate2dDragMeComponent(string name, out Components.DragMe comp)
        {
            GameObject go = new GameObject(name);
            go.transform.position = Vector2.zero;

            Rigidbody2D rb = go.AddComponent<Rigidbody2D>();
            
            // Config rigidbody.
            rb.isKinematic = true;
            rb.interpolation = RigidbodyInterpolation2D.Interpolate;

            // Add sprite.
            GameObject so = new GameObject("New Sprite");
            so.transform.SetParent(go.transform);
            so.transform.localPosition = Vector3.zero;
            SpriteRenderer sr = so.AddComponent<SpriteRenderer>();

            // Add collider.
            BoxCollider2D c = so.AddComponent<BoxCollider2D>();
            c.isTrigger = true;
            c.size = Vector2.one;

            comp = go.AddComponent<Components.DragMe>();
            return true;
        }

        private static bool TryCreate3dDragMeComponent(string name, out Components.DragMe comp)
        {
            GameObject go = new GameObject(name);
            go.transform.position = Vector3.zero;

            Rigidbody rb = go.AddComponent<Rigidbody>();

            // Configure rigidbody.
            rb.useGravity = false;
            rb.isKinematic = true;
            rb.interpolation = RigidbodyInterpolation.Interpolate;

            // Add model.
            GameObject cube = GameObject.CreatePrimitive(PrimitiveType.Cube);
            cube.transform.SetParent(go.transform);
            cube.transform.localPosition = Vector3.zero;
            cube.transform.localScale = new Vector3(1f, 0.25f, 1.5f);

            // Configure collider.
            BoxCollider c = cube.GetComponent<BoxCollider>();
            c.isTrigger = true;

            comp = go.AddComponent<Components.DragMe>();
            return true;
        }

        private static void RegisterEvents(ref Components.DragMe comp)
        {
            // Register GrabMe callback.
            UnityEditor.Events.UnityEventTools.AddPersistentListener<IGrabbedEventData>(comp.e_Grabbed, 
                System.Delegate.CreateDelegate(typeof(UnityAction<IGrabbedEventData>), comp, "GrabMe") as UnityAction<IGrabbedEventData>);

            // Register MoveMe callback.
            UnityEditor.Events.UnityEventTools.AddPersistentListener<IDraggedEventData>(comp.e_Dragged, 
                System.Delegate.CreateDelegate(typeof(UnityAction<IDraggedEventData>), comp, "MoveMe") as UnityAction<IDraggedEventData>);

            // Register ReleaseMe callback.
            UnityEditor.Events.UnityEventTools.AddPersistentListener<IReleasedEventData>(comp.e_Released, 
                System.Delegate.CreateDelegate(typeof(UnityAction<IReleasedEventData>), comp, "ReleaseMe") as UnityAction<IReleasedEventData>);

            // Register PlaceMe callback.
            UnityEditor.Events.UnityEventTools.AddPersistentListener<IPlacedEventData>(comp.e_Placed, 
                System.Delegate.CreateDelegate(typeof(UnityAction<IPlacedEventData>), comp, "PlaceMe") as UnityAction<IPlacedEventData>);

            // Register ResetToStart callback.
            UnityEditor.Events.UnityEventTools.AddPersistentListener<IResetEventData>(comp.e_Reset, 
                System.Delegate.CreateDelegate(typeof(UnityAction<IResetEventData>), comp, "ResetToStart") as UnityAction<IResetEventData>);
        } 

        [MenuItem(BASE_PATH_2D + "DragMe Hold 2d")]
        public static void CreateHold2dObject()
        {
            if(!TryCreate2dDragMeComponent("DragMe Hold 2d", out Components.DragMe lComp))
                return;
            
            // Assign config.
            lComp.Config = Resources.Load<DragMeConfig>(Constants.Hold2dConfigName);

            RegisterEvents(ref lComp);
        }

        [MenuItem(BASE_PATH_2D + "DragMe Toggle 2d")]
        public static void CreateToggle2dObject()
        {
            if(!TryCreate2dDragMeComponent("DragMe Toggle 2d", out Components.DragMe lComp))
                return;
            
            // Assign config.
            lComp.Config = Resources.Load<DragMeConfig>(Constants.Toggle2dConfigName);

            RegisterEvents(ref lComp);
        }

        [MenuItem(BASE_PATH_3D + "DragMe Hold 3d")]
        public static void CreateHold3dObject()
        {
            if(!TryCreate3dDragMeComponent("DragMe Hold 3d", out Components.DragMe lComp))
                return;
            
            // Assign config.
            lComp.Config = Resources.Load<DragMeConfig>(Constants.Hold3dConfigName);

            RegisterEvents(ref lComp);
        }

        [MenuItem(BASE_PATH_3D + "DragMe Toggle 3d")]
        public static void CreateToggle3dObject()
        {
            if(!TryCreate3dDragMeComponent("DragMe Toggle 3d", out Components.DragMe lComp))
                return;
            
            // Assign config.
            lComp.Config = Resources.Load<DragMeConfig>(Constants.Toggle3dConfigName);

            RegisterEvents(ref lComp);
        }
    }
}