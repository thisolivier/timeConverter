// __APP_NAME__ for Android: Gradle settings.
//
// Two modules: `core` is a plain Kotlin/JVM library (logic, no Android
// imports, tested on the JVM in seconds without an emulator) and `app` is the
// thin Jetpack Compose shell over it.
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

rootProject.name = "__APP_NAME__"
include(":core")
include(":app")
