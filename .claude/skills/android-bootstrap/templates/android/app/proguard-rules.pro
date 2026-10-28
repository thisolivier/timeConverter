# R8 keep rules for release builds (isMinifyEnabled = true).
#
# Empty on purpose: Compose and plain Kotlin need none. Add rules only when the
# release smoke (scripts/ship-android.sh step 5) shows something R8 broke:
# typically reflection, kotlinx.serialization serializers, or classpath
# resources. Example for kotlinx.serialization models in :core:
#   -keepclassmembers class __APPLICATION_ID__.core.** { *** Companion; }
#   -keepclasseswithmembers class __APPLICATION_ID__.core.** {
#       kotlinx.serialization.KSerializer serializer(...);
#   }
