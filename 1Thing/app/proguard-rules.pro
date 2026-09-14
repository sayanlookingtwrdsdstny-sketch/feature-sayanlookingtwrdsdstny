# Room
-keep class * extends androidx.room.RoomDatabase
-keepclasseswithmembers class * {
    @androidx.room.* <methods>;
}
-keepclasseswithmembers class * {
    @androidx.room.* <fields>;
}
-keep @interface androidx.room.*

# Serialization
-keepclassmembers class * {
    @kotlinx.serialization.Serializable <methods>;
}
-keepclasseswithmembers class * {
    @kotlinx.serialization.Serializable <fields>;
}
-keep @interface kotlinx.serialization.**

# Coroutines
-keep class kotlinx.coroutines.** { *; }
-keepclassmembers class kotlinx.coroutines.** {
    volatile <fields>;
}

# General
-keepattributes *Annotation*, InnerClasses
-dontnote junit.framework.**
-dontnote junit.runner.**
-dontwarn androidx.**
-verbose
