# Keep Firebase and Crashlytics classes from being obfuscated or stripped by R8/ProGuard
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
