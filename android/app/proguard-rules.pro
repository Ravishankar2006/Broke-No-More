# Flutter's embedding and the deferred-components API are referenced only
# from generated/reflective call sites that R8 can't trace statically.
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }

# flutter_local_notifications resolves these by class name from the
# AndroidManifest <receiver> entries (see StreakReminderService), which R8
# can't see as a real reference.
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Gson (pulled in transitively by several plugins) walks model fields via
# reflection at runtime.
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }

# Flutter's engine references the Play Feature Delivery (deferred
# components) API defensively even though this app doesn't use split
# installs, so the classes are legitimately absent from the classpath.
# This is Flutter's own documented fix, not an app-specific workaround.
-dontwarn com.google.android.play.core.**
