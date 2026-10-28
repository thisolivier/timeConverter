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

// Two of the Swift core's resources ride on this module's classpath straight
// from their one file, so there is no second copy to drift:
// - `/zone-names.json`, the zone-name snapshot captured on iOS (iOS is the
//   origin — see fixtures/readme.md);
// - `/fallback-cities.json`, the offline gazetteer (resolver step 5).
tasks.processResources {
    val swiftResources = "../TimeConverterCore/Sources/TimeConverterCore/Resources"
    from(rootProject.file("$swiftResources/zone-names.json"))
    from(rootProject.file("$swiftResources/fallback-cities.json"))
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
