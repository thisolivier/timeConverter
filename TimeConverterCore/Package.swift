// swift-tools-version: 6.2
//
// `6.2` rather than `6.0` is forced, not stylistic: `.iOS(.v26)` / `.macOS(.v26)`
// only exist from PackageDescription 6.2, and an older tools version fails with
// "'v26' is unavailable". The Swift *language* mode is still 6 — that is the
// default for tools 6.x — so this package compiles under the same strict
// concurrency rules as the two app targets.
import PackageDescription

let package = Package(
    name: "TimeConverterCore",
    // Matched to the two shells' deployment targets in project.yml. A package
    // may not declare a *lower* floor than its consumer without the consumer
    // inheriting it, and a higher one fails the build outright, so these two
    // numbers and project.yml's `deploymentTarget` move together.
    platforms: [
        .iOS(.v26),
        .macOS(.v26)
    ],
    products: [
        // One product, one target. The split inside `Sources/` (Parsing,
        // Presentation, Launch) is organisational: making them separate SPM
        // targets would force the parsing internals public to the presenter,
        // which is the opposite of the goal.
        .library(
            name: "TimeConverterCore",
            targets: ["TimeConverterCore"]
        )
    ],
    targets: [
        .target(
            name: "TimeConverterCore",
            // Module readmes are documentation, not resources. Without this,
            // SwiftPM warns "found an unhandled resource" and would otherwise
            // copy them into the product.
            exclude: ["Parsing/readme.md"],
            // `.process` rather than `.copy`: it goes through the asset
            // pipeline and lands flat in the generated resource bundle, which
            // is what `Bundle.module.url(forResource:withExtension:)` expects.
            resources: [.process("Resources/fallback-cities.json")]
        ),
        .testTarget(
            name: "TimeConverterCoreTests",
            dependencies: ["TimeConverterCore"]
        )
    ]
)
