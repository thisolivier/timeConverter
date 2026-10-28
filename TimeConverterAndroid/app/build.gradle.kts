// `app` — the Android shell: one Compose activity over `:core`.
//
// Version numbers are READ FROM ../project.yml rather than duplicated here, so
// the Play train shares `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` with
// the iOS and macOS trains, the same way scripts/lib/version.sh does for the
// Apple ship scripts. One number to bump, three stores.
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
        versionName = appleProjectSetting("MARKETING_VERSION")
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            // Release signing is configured in a later session (Play upload
            // key); until then release builds are unsigned and `run-android.sh`
            // installs the debug variant.
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
