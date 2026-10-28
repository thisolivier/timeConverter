// TimeConverter for Android — Gradle settings.
//
// Two modules, mirroring the Apple side's split: `core` is a plain Kotlin/JVM
// library (parser, engine, presenter — no Android imports, testable in
// milliseconds without an emulator), and `app` is the thin Compose shell.
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "TimeConverter"
include(":core")
include(":app")
