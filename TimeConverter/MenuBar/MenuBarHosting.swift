import Foundation

/// The one seam between the Catalyst app and the macOS-SDK bundle that gives it
/// a menu-bar presence (backlog item 12a).
///
/// This file is compiled into **both** targets — the iOS/Catalyst app and the
/// macOS `TimeConverterMenuBar` bundle (see `project.yml`). Two separate
/// compilations against two different SDKs have to agree on one runtime
/// identity, which is why there are some unusually strict rules here:
///
/// - **`@objc(MenuBarHosting)` is load-bearing.** With a plain
///   `@objc public protocol`, the bundle loads and its principal class
///   resolves, but the cast to this protocol *fails*: each module mangles the
///   protocol's runtime name differently and the two disagree. The explicit
///   ObjC name pins it. The implementation side needs the matching
///   `@objc public required override init()`.
/// - **`Foundation` only.** Anything SDK-specific here would have to mean the
///   same thing on iOS and macOS, and `@available`/`#available` are actively
///   misleading inside the bundle (it is a macOS-platform binary, so iOS
///   predicates are meaningless there).
/// - **No SPM.** Archiving a Catalyst app that embeds a macOS target fails with
///   "Multiple commands produce …" if both targets depend on the same local
///   Swift package. Keeping this file dependency-free sidesteps that.
///
/// Everything the app does with a conforming object is optional-by-design: if
/// the bundle is missing, stale, unsigned or simply refuses to load, the app
/// logs it and runs on without a menu bar.
/// `@MainActor` because every call behind it is: `NSStatusItem` requires the
/// main thread, the Carbon hotkey APIs are documented "not thread safe", and
/// the app side is main-actor already. Stating it here is what keeps both
/// compilations honest instead of warning-suppressed.
@MainActor
@objc(MenuBarHosting)
public protocol MenuBarHosting: NSObjectProtocol {
    /// Instantiated reflectively from the bundle's `NSPrincipalClass`, so the
    /// initialiser has to be part of the contract.
    init()

    /// Puts the status item in the menu bar and registers the global hotkey.
    ///
    /// Call on the main thread. `onSummon` is invoked on the main thread every
    /// time the user clicks the status item or presses the hotkey; it may be
    /// called any number of times, including never.
    ///
    /// Returns a one-line, human-readable summary of what actually came up, for
    /// the app's log — "status item + ⌃⌥T", "status item only (hotkey held
    /// elsewhere)", and so on. Deliberately not a `Bool`: a partially working
    /// menu bar is a normal outcome worth naming, never an error worth
    /// failing the launch over.
    func start(onSummon: @escaping () -> Void) -> String

    /// Removes the status item and unregisters the hotkey. Idempotent.
    ///
    /// Belt and braces only: hotkey registration is WindowServer state keyed to
    /// the process, and the system reclaims it however the process dies —
    /// Apple's own header says so — so a crash strands nothing.
    func stop()
}
