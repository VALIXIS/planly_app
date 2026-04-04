## Flutter ProGuard rules
# Keep Flutter classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
# Keep generated plugin registrant
-keep class com.js.planly.GeneratedPluginRegistrant { *; }
# Add rules for your plugins if needed
