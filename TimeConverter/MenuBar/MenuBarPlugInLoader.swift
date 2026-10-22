import Foundation
import os

/// Where the menu-bar bundle lives and what it is called at runtime.
///
/// Three names that must agree with `project.yml` and with the bundle's own
/// source, and which nothing but the loader should care about. They are
/// constants rather than literals so the tests can assert the two that the
/// compiler cannot check for us (see `MenuBarPlugInTests`).
enum MenuBarPlugIn {
    /// `PRODUCT_NAME` + `WRAPPER_EXTENSION` of the `TimeConverterMenuBar`
    /// target, which is the filename it is copied into `Contents/PlugIns` as.
    static let bundleFileName = "TimeConverterMenuBar.bundle"

    /// The bundle's `NSPrincipalClass`, i.e. the `@objc(…)` name of
    /// `MenuBarController` — not its Swift-mangled name.
    static let principalClassName = "MenuBarController"

    /// The `@objc(…)` name of `MenuBarHosting`. The cast across the bundle
    /// boundary resolves through this string, so if it ever stops being
    /// exported the menu bar silently stops loading.
    static let hostingProtocolName = "MenuBarHosting"

    static let logger = Logger(
        subsystem: "dev.thisolivier.timeconverter", category: "menubar"
    )
}

/// Loads the menu-bar bundle, or explains why it could not.
///
/// **Every step is optional and none of them is fatal.** `builtInPlugInsURL`
/// may be nil, the file may be absent (a plain iOS build has no `PlugIns` at
/// all), `Bundle(url:)` may refuse it, `loadAndReturnError()` may fail on a
/// signature or an architecture mismatch, the principal class may be missing,
/// and the protocol cast may fail even when everything else worked — that last
/// one is the real trap this whole design is shaped around. Each returns a
/// `nil` host and a sentence saying which, and the app carries on without a
/// menu bar.
///
/// Compiled on every platform even though only Mac Catalyst ever calls it: the
/// code is Foundation-only, and keeping it out of a `#if` is what lets both
/// test lanes exercise the failure paths.
enum MenuBarPlugInLoader {
    struct Result {
        /// The loaded object, or nil when the menu bar is simply not available.
        let host: MenuBarHosting?
        /// One line for the log, always present, success or failure.
        let diagnostic: String
    }

    /// The bundle's expected location: `…/TimeConverter.app/Contents/PlugIns/`.
    ///
    /// `Bundle.main.builtInPlugInsURL` resolves correctly for a Catalyst app —
    /// no hand-built `Contents/PlugIns` path needed — and resolves to a
    /// directory that does not exist on iOS, which is exactly the right answer
    /// there.
    static func expectedBundleURL(
        inPlugInsDirectory plugInsDirectory: URL? = Bundle.main.builtInPlugInsURL
    ) -> URL? {
        plugInsDirectory?.appendingPathComponent(MenuBarPlugIn.bundleFileName)
    }

    static func loadHost(at bundleURL: URL?) -> Result {
        guard let bundleURL else {
            return Result(host: nil, diagnostic: "no PlugIns directory")
        }
        guard FileManager.default.fileExists(atPath: bundleURL.path) else {
            return Result(host: nil, diagnostic: "not present at \(bundleURL.path)")
        }
        guard let bundle = Bundle(url: bundleURL) else {
            return Result(host: nil, diagnostic: "Bundle(url:) rejected \(bundleURL.path)")
        }
        do {
            // `loadAndReturnError()` rather than `load()`: the thrown error is
            // the only way to tell a signature failure from an architecture
            // mismatch from a missing dependency.
            try bundle.loadAndReturnError()
        } catch {
            return Result(host: nil, diagnostic: "load failed: \(error.localizedDescription)")
        }
        guard let principalClass = bundle.principalClass as? NSObject.Type else {
            return Result(host: nil, diagnostic: "no NSPrincipalClass named \(MenuBarPlugIn.principalClassName)")
        }
        guard let host = principalClass.init() as? MenuBarHosting else {
            return Result(
                host: nil,
                diagnostic: "\(principalClass) is not \(MenuBarPlugIn.hostingProtocolName) —"
                    + " check @objc(\(MenuBarPlugIn.hostingProtocolName)) survived both compilations"
            )
        }
        return Result(host: host, diagnostic: "loaded \(bundleURL.lastPathComponent)")
    }
}
