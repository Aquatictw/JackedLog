# Spotify SDK - Keep all Spotify classes
-keep class com.spotify.** { *; }
-keep interface com.spotify.** { *; }
-keep enum com.spotify.** { *; }

# Keep Spotify protocol types
-keep class com.spotify.protocol.types.** { *; }
-keep class com.spotify.protocol.client.** { *; }
-keep class com.spotify.protocol.mappers.** { *; }

# Suppress warnings for Spotify protocol types (loaded at runtime)
-dontwarn com.spotify.protocol.types.**
-dontwarn com.spotify.protocol.client.**
-dontwarn com.spotify.protocol.mappers.**

# Keep Spotify SDK annotations
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions

# Gson (used by Spotify SDK)
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Keep generic signature of Spotify SDK classes
-keepattributes Signature

# Fix missing classes errors for Spotify SDK and dependencies
-dontwarn com.spotify.base.annotations.**
-dontwarn javax.annotation.**
-dontwarn javax.xml.stream.**
