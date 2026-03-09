using Studio.OverOne.DragMe.Integrations.Abstractions;
using UnityEngine;

namespace Studio.OverOne.DragMe.Integrations.Unity
{
    public sealed class UnityInputSource : InputSourceBase
    {
        // True when the Left Mouse Button is Pressed, false otherwise.
        public override bool Grab => Input.GetMouseButtonDown(0);

        // True when the Left Mouse Button is Held, false otherwise.
        public override bool Hold => Input.GetMouseButton(0);

        // True when the Left Mouse Button is released, false otherwise.
        public override bool Release => Input.GetMouseButtonUp(0);
    }
}