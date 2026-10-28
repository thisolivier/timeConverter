// `core` — the shared engine, as a plain JVM library. No Android dependency on
// purpose: `java.time` already ships the IANA zone database and DST rules, and
// keeping Android out of here is what lets the fixture suite run on the JVM in
// a second instead of on an emulator in a minute.
plugins {
    alias(libs.plugins.kotlin.jvm)
    alias(libs.plugins.kotlin.serialization)
}

kotlin {
    jvmToolchain(17)
}

dependencies {
    implementation(libs.kotlinx.serialization.json)
    testImplementation(kotlin("test"))
}

tasks.test {
    useJUnitPlatform()
    testLogging {
        events("passed", "skipped", "failed")
        showStandardStreams = false
    }
}

// The fixture file lives at the repository root so both cores can reach it.
tasks.withType<Test>().configureEach {
    systemProperty("timeconverter.fixtures", rootProject.file("../fixtures/conversion-cases.json").absolutePath)
}
