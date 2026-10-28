import java.util.Properties

// `app` — the Android shell: one Compose activity over `:core`.
//
// Version numbers are READ FROM ../project.yml rather than duplicated here, so
// the Android train shares `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` with
// the iOS and macOS trains, the same way scripts/lib/version.sh does for the
// Apple ship scripts. One number to bump, three trains.
plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
}

val appleProjectFile = rootProject.file("../project.yml")
fun appleProjectSetting(name: String): String {
    val pattern = Regex("""^\s*$name:\s*"?([^"\s]+)"?\s*$""", RegexOption.MULTILINE)
    return pattern.find(appleProjectFile.readText())?.groupValues?.get(1)
        ?: error("$name not found in ${appleProjectFile.path}")
}

// Release signing reads the key made by scripts/setup-android-signing.sh, which
// lives outside the repo. A clean clone has no such file: release then builds
// unsigned (with a warning) instead of failing, so `assembleRelease` still
// works for anyone. scripts/ship-android.sh refuses to publish an unsigned APK.
val releaseSigningPropertiesFile = File(System.getProperty("user.home"), ".config/timeconverter/android-release.properties")
val releaseSigningProperties = Properties().apply {
    if (releaseSigningPropertiesFile.isFile) releaseSigningPropertiesFile.inputStream().use { load(it) }
}
val hasReleaseSigningKey = releaseSigningProperties.getProperty("storeFile") != null
if (!hasReleaseSigningKey) {
    logger.warn("TimeConverter: ${releaseSigningPropertiesFile.path} not found — release builds will be UNSIGNED. Run scripts/setup-android-signing.sh.")
}

android {
    namespace = "dev.thisolivier.timeconverter"
    compileSdk = 37

    defaultConfig {
        // Same reverse-DNS id as the Apple bundle — unrelated to it technically
        // (Play and App Store Connect are different namespaces) but one name
        // for one product is easier to reason about.
        applicationId = "dev.thisolivier.timeconverter"
        // 26 = Android 8.0: java.time without desugaring, and ~99% of devices.
        minSdk = 26
        targetSdk = 36
        versionCode = appleProjectSetting("CURRENT_PROJECT_VERSION").toInt()
        // MARKETING_VERSION + "." + build, e.g. 0.1.0.17. The build number is in
        // the name because Obtainium (the partner's update channel, see
        // docs/android-distribution.md) compares the GitHub release tag
        // (`android-0.1.0.17`) with the installed versionName, and the
        // marketing version alone stays the same across many builds.
        versionName = appleProjectSetting("MARKETING_VERSION") + "." + appleProjectSetting("CURRENT_PROJECT_VERSION")
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
