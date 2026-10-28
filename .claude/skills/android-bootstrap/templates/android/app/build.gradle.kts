import java.util.Properties

// `app`: the Android shell, one Compose activity over `:core`.
plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
}

// Version numbers live in ../version.properties (repo root), which
// scripts/ship-android.sh bumps. A project that also ships Apple builds can
// point these two lookups at its shared source (e.g. project.yml) instead.
val versionProperties = Properties().apply {
    rootProject.file("../version.properties").inputStream().use { load(it) }
}
val appVersionName: String = versionProperties.getProperty("VERSION_NAME") ?: error("VERSION_NAME missing")
val appBuildNumber: Int = versionProperties.getProperty("BUILD_NUMBER")?.toInt() ?: error("BUILD_NUMBER missing")

// Release signing reads the key made by scripts/setup-android-signing.sh,
// which lives outside the repo. A clean clone has no such file: release then
// builds UNSIGNED (with a warning) instead of failing, so `assembleRelease`
// works for anyone. scripts/ship-android.sh refuses to publish unsigned.
val releaseSigningPropertiesFile = File(
    providers.environmentVariable("ANDROID_SIGNING_PROPERTIES").orNull
        ?: "${System.getProperty("user.home")}/.config/__APPLICATION_ID__/android-release.properties"
)
val releaseSigningProperties = Properties().apply {
    if (releaseSigningPropertiesFile.isFile) releaseSigningPropertiesFile.inputStream().use { load(it) }
}
val hasReleaseSigningKey = releaseSigningProperties.getProperty("storeFile") != null
if (!hasReleaseSigningKey) {
    logger.warn("__APP_NAME__: ${releaseSigningPropertiesFile.path} not found; release builds will be UNSIGNED. Run scripts/setup-android-signing.sh.")
}

android {
    namespace = "__APPLICATION_ID__"
    compileSdk = 37 // the Compose BOM demands it; targetSdk can stay a step behind

    defaultConfig {
        applicationId = "__APPLICATION_ID__"
        minSdk = 26 // Android 8.0: java.time without desugaring, ~99% of devices
        targetSdk = 36
        versionCode = appBuildNumber
        // VERSION_NAME + "." + build, e.g. 0.1.0.17. Obtainium compares the
        // GitHub release tag (android-0.1.0.17) with the installed versionName,
        // and VERSION_NAME alone stays the same across many builds.
        versionName = "$appVersionName.$appBuildNumber"
    }

    signingConfigs {
        if (hasReleaseSigningKey) {
            create("release") {
                storeFile = file(releaseSigningProperties.getProperty("storeFile"))
                storePassword = releaseSigningProperties.getProperty("storePassword")
                keyAlias = releaseSigningProperties.getProperty("keyAlias")
                keyPassword = releaseSigningProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            if (hasReleaseSigningKey) signingConfig = signingConfigs.getByName("release")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        compose = true
    }
}

dependencies {
    implementation(project(":core"))
    val composeBom = platform(libs.compose.bom)
    implementation(composeBom)
    androidTestImplementation(composeBom)
    implementation(libs.compose.material3)
    implementation(libs.compose.ui)
    implementation(libs.compose.ui.tooling.preview)
    implementation(libs.activity.compose)
    debugImplementation(libs.compose.ui.tooling)
    debugImplementation(libs.compose.ui.test.manifest)
    testImplementation(libs.junit)
    androidTestImplementation(libs.compose.ui.test.junit4)
}
