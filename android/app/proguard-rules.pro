# Unity Integration Rules
-keep class com.xraph.plugin.flutter_unity_widget.** { *; }
-keep class com.unity3d.player.** { *; }

# Prevent stripping of IL2CPP symbols
-keep class com.unity3d.player.UnityPlayer { *; }
-keep interface com.unity3d.player.** { *; }

# Keep Flutter methods
-keep class io.flutter.plugin.common.** { *; }
