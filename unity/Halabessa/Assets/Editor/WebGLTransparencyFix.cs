using UnityEditor;
using UnityEngine;

namespace Halabessa.Editor {
    public class WebGLTransparencyFix : EditorWindow {
        [MenuItem("Halabessa/Fix WebGL Transparency")]
        public static void ApplyFix() {
            // Force Linear Color Space for modern WebGL 2.0 transparency
            PlayerSettings.colorSpace = ColorSpace.Linear;
            // CRITICAL: Preserve Alpha channel in the framebuffer
            PlayerSettings.preserveFramebufferAlpha = true;
            // Configure Optimization
            PlayerSettings.WebGL.compressionFormat = WebGLCompressionFormat.Brotli;
            // Disable fallback as it can interfere with canvas rendering in some browsers
            PlayerSettings.WebGL.decompressionFallback = false; 

            Debug.Log("✅ WebGL Transparency Fix Applied: Linear Color Space + Alpha Preserved + Fallback Disabled.");
        }
    }
}
