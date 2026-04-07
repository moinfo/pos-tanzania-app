# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep Flutter engine
-keep class io.flutter.embedding.** { *; }

# Dart/Flutter entry point
-keep class ** extends io.flutter.embedding.android.FlutterActivity { *; }
-keep class ** extends io.flutter.embedding.android.FlutterFragment { *; }

# Suppress warnings for missing classes from unused deps
-dontwarn io.flutter.embedding.**