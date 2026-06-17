# Flutter wrapper — Flutter's own classes are kept by the Flutter Gradle plugin.

# ObjectBox: keep generated model/entity classes and native bindings.
-keep class io.objectbox.** { *; }
-keep @io.objectbox.annotation.Entity class * { *; }
-keepclassmembers class * {
    @io.objectbox.annotation.Id <fields>;
}
-dontwarn io.objectbox.**

# Keep annotations used by reflection-based libraries.
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod
