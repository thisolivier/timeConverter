# kotlinx.serialization: keep the generated serializers for the fixture models.
-keepclassmembers class dev.thisolivier.timeconverter.core.** {
    *** Companion;
}
-keepclasseswithmembers class dev.thisolivier.timeconverter.core.** {
    kotlinx.serialization.KSerializer serializer(...);
}
