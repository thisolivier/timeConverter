// `core`: the app's logic as a plain JVM library. No Android dependency on
// purpose, so its tests run on the JVM in a second instead of on an emulator
// in a minute. Keep everything that is not a view here.
plugins {
    alias(libs.plugins.kotlin.jvm)
}

kotlin {
    jvmToolchain(17)
}

dependencies {
    testImplementation(kotlin("test"))
}

tasks.test {
    useJUnitPlatform()
    testLogging {
        events("passed", "skipped", "failed")
        showStandardStreams = false
    }
}
