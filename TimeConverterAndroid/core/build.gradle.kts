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

// The zone-name snapshot is the Swift core's resource, captured on iOS (iOS is
// the origin — see fixtures/readme.md). It is added to this module's classpath
// as `/zone-names.json` straight from that one file: there is no second copy
// to drift.
tasks.processResources {
    from(rootProject.file("../TimeConverterCore/Sources/TimeConverterCore/Resources/zone-names.json"))
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
