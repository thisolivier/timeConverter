import AppKit
import SwiftUI
import TimeConverterUI

/// The summoned panel, which differs from a stock `NSPanel` in exactly two
/// ways — both of them consequences of having no title bar.
///
/// `canBecomeKey` is asserted rather than inherited: `NSPanel` grants it for a
/// `.titled` window already, but this window's title bar is invisible and the
/// next person to reach for `.borderless` here would lose the keyboard without
/// any obvious connection between the two. Saying it out loud costs a line and
/// documents the constraint.
///
/// `cancelOperation` is the esc key arriving at the end of the responder chain.
/// It only gets there when the field editor has not already consumed it, which
/// is the behaviour that is wanted: esc inside a text field that is mid-edit
/// belongs to the field, and esc otherwise means "put this away".
private final class SummonedGlassPanel: NSPanel {
    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        orderOut(nil)
    }
}

/// Owns ⌃⌥T and the thing it summons.
///
/// The summoned thing is the **glass panel of page 3** (backlog item 20, phase
/// B) — a transparent, chromeless, fixed-width `NSPanel` floating over whatever
/// the user was looking at. It was a plain titled placeholder until phase B;
/// the plumbing around it (the toggle rule, the focus ladder, the logging) is
/// unchanged, and only the window's dress and its contents are new.
///
/// A panel rather than a programmatically opened `MenuBarExtra` dropdown
/// because SwiftUI exposes no way to open a `MenuBarExtra` from code — doing it
/// anyway means synthesising a click on a status item SwiftUI never hands you,
/// which is more code and more fragile than forty lines of `NSPanel`.
///
/// Main-actor throughout: AppKit windows require it and the Carbon hotkey
/// callback is delivered there.
@MainActor
final class PanelSummoner {
    private var hotKey: GlobalHotKey?
    private var panel: NSPanel?

    /// QA affordance: `-summonOnLaunch 1` opens the panel at launch.
    ///
    /// Two jobs, both of them about the one thing a headless machine cannot do.
    /// Synthetic keystrokes are TCC-blocked (see the header of
    /// `scripts/qa-menubar.sh`), so without this *nothing automated ever builds
    /// the panel* — the summon path is reached only by a human pressing ⌃⌥T,
    /// and a crash in `makePanel` would wait there to be found by hand. And for
    /// the human, it saves switching to another app first when the thing being
    /// checked is the glass rather than the hotkey.
    ///
    /// **DEBUG only.** A shipped menu-bar utility that opens a window at launch
    /// is not a menu-bar utility.
    static let summonOnLaunchKey = "summonOnLaunch"

    /// Called once from `applicationDidFinishLaunching`. Idempotent.
    func start() {
        guard hotKey == nil else { return }
        #if DEBUG
        if UserDefaults.standard.bool(forKey: Self.summonOnLaunchKey) {
            summon()
        }
        #endif
        let hotKey = GlobalHotKey { [weak self] in self?.summon() }
        self.hotKey = hotKey
        let registration = hotKey.register()

        // One deferred log line covering both halves, because the status item
        // is created by the `MenuBarExtra` scene and does not exist yet at
        // `applicationDidFinishLaunching`. Deferred rather than observed: the
        // scene has no completion callback, and this line is diagnostics, not
        // control flow.
        Task { @MainActor [registration] in
            try? await Task.sleep(for: .milliseconds(500))
            MacMenuBarLog.logger.notice(
                """
                menu bar ready: native macOS shell \
                — \(Self.statusItemSummary(), privacy: .public) \
                + \(registration.description, privacy: .public)
                """
            )
        }
    }

    /// Idempotent, and belt-and-braces: hotkey registration is per-process
    /// WindowServer state that the system reclaims however the process dies.
    func stop() {
        hotKey?.unregister()
        hotKey = nil
        panel?.orderOut(nil)
    }

    /// ⌃⌥T, or anything else that means "show me the converter".
    func summon() {
        let action = SummonPolicy.action(
            panelIsVisible: panel?.isVisible == true,
            appIsActive: NSApp.isActive
        )
        MacMenuBarLog.logger.notice(
            "hotkey received: ⌃⌥T — \(String(describing: action), privacy: .public)"
        )
        switch action {
        case .hide:
            panel?.orderOut(nil)
        case .show:
            let panel = panel ?? makePanel()
            self.panel = panel
            // An accessory-policy app is never frontmost by accident, so it has
            // to ask — otherwise the panel appears behind the app the user was
            // in and cannot take the keyboard.
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
        }

        // Item 17. Raised *after* the window work, so by the time the view
        // reacts the panel is already key and the first rung of the focus
        // ladder has a chance of landing. The later rungs cover the case where
        // it does not.
        if SummonPolicy.requestsInputFocus(for: action) {
            SummonFocusRequests.shared.request()
        }
    }

    // MARK: - The glass panel

    /// A window with no chrome of its own, so that the only thing on screen is
    /// the design.
    ///
    /// Each of these lines is load-bearing, and most of them are fighting the
    /// same battle — AppKit's defaults assume a window wants to look like a
    /// window:
    ///
    /// - **`.titled`, still.** A `.borderless` window cannot become key, and
    ///   this one's whole job is to take typed input. So the title bar stays in
    ///   the style mask and is then made invisible: transparent, no title, and
    ///   its three standard buttons hidden. `.fullSizeContentView` hands the
    ///   space back to the content.
    /// - **No close button**, which is why the footer says how to dismiss it
    ///   (`GlassFooterText`) and why `cancelOperation` is overridden below.
    ///   A traffic light on a 30pt-radius glass panel is the one piece of
    ///   chrome that would make it look like a window that lost its title bar.
    /// - **Transparent and shadowed.** `isOpaque = false` plus a clear
    ///   background is what lets the rounded corners actually be round, and
    ///   `hasShadow` then gets AppKit to compute the drop shadow from the
    ///   content's own alpha — the design's `box-shadow`, drawn by the system,
    ///   in the system's own idiom. See `GlassPanelSurface` for why that beat
    ///   drawing it by hand.
    /// - **A content *controller*, not a content view.** `NSHostingController`
    ///   makes the window track the SwiftUI content's fitting size, so the
    ///   panel is exactly as tall as the design needs at 740pt wide and
    ///   re-sizes itself when a prompt replaces a conversion. `setContentSize`
    ///   keeps the top-left corner fixed, so it grows downward rather than
    ///   appearing to jump.
    /// - **Not resizable.** No `.resizable` in the mask: working assumption 3
    ///   of the sprint plan. This is a composition at a fixed internal
    ///   proportion — 124pt numerals against a 12pt label — and a user-dragged
    ///   width would turn that into an accident.
    private func makePanel() -> NSPanel {
        let hostingController = NSHostingController(
            rootView: MenuBarConverterView(presentation: .summonedPanel)
        )
        // Stated rather than left to the default. Without it the window is
        // sized once, from whatever the content measured before `onAppear` had
        // run — which is the empty hint — and then never grows: the 124pt
        // numerals of an actual conversion get squeezed into the height of a
        // one-line placeholder. Measured, not theorised: the panel came up
        // 740×279 for every state until this line existed.
        hostingController.sizingOptions = .preferredContentSize
        let panel = SummonedGlassPanel(
            contentRect: NSRect(
                x: 0, y: 0, width: GlassPanelMetrics.wide.totalWidth, height: 1
            ),
            styleMask: [.titled, .fullSizeContentView, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = hostingController

        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        for button: NSWindow.ButtonType in [.closeButton, .miniaturizeButton, .zoomButton] {
            panel.standardWindowButton(button)?.isHidden = true
        }

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        // No title bar means no handle, so the glass itself is the handle.
        panel.isMovableByWindowBackground = true

        panel.isFloatingPanel = true
        panel.level = .floating
        // Without this an AppKit panel is deallocated by its own close button
        // and the next ⌃⌥T uses a dangling reference.
        panel.isReleasedWhenClosed = false
        // Summoned onto whatever Space and full-screen app the user is in,
        // which is the behaviour the hotkey implies.
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.center()
        return panel
    }

    /// Whether the `MenuBarExtra` status item actually made it into the menu
    /// bar, as far as anything headless can tell.
    ///
    /// SwiftUI owns the `NSStatusItem` and never hands it over, so the only
    /// available evidence is that the process has a status-bar window. The
    /// class name is read as a string rather than referenced, because it is
    /// private API: a rename costs this one log line and nothing else.
    private static func statusItemSummary() -> String {
        let hasStatusBarWindow = NSApp.windows.contains {
            String(describing: type(of: $0)).contains("StatusBar")
        }
        return hasStatusBarWindow ? "status item" : "no status item"
    }
}
