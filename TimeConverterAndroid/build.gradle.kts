// Root build file: declares plugin versions once (from gradle/libs.versions.toml)
// so each module just applies them. AGP 9 compiles Kotlin itself ("built-in
// Kotlin"), so the app module applies no kotlin-android plugin; putting the
// Kotlin Gradle plugin on this classpath via kotlin-jvm is what gives AGP its
// Kotlin version.
plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.kotlin.jvm) apply false
    alias(libs.plugins.kotlin.compose) apply false
    alias(libs.plugins.kotlin.serialization) apply false
}
