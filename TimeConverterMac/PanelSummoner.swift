import AppKit
import SwiftUI

/// Owns ⌃⌥T and the thing it summons.
///
/// The summoned thing is a **plain floating `NSPanel`** and that is a
/// deliberate placeholder: `docs/ux-v1-proposal.md` wants a translucent
/// Spotlight-style modal, which is a design job, not a plumbing job. A panel
/// was chosen over programmatically opening the `MenuBarExtra` dropdown because
/// SwiftUI exposes no way to open a `MenuBarExtra` from code — doing it anyway
/// means synthesising a click on a status item SwiftUI never hands you, which
/// is more code and more fragile than thirty lines of `NSPanel` for something
/// that is going to be replaced by the real design anyway.
///
/// Main-actor throughout: AppKit windows require it and the Carbon hotkey
/// callback is delivered there.
@MainActor
final class PanelSummoner {
    private var hotKey: GlobalHotKey?
    private var panel: NSPanel?

    /// Called once from `applicationDidFinishLaunching`. Idempotent.
    func start() {
        guard hotKey == nil else { return }
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

    // MARK: - The placeholder panel

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 220),
            // `.titled` and not `.nonactivatingPanel`: the panel's whole job is
            // to take typed input, and a non-activating panel cannot become key.
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "Time Converter"
        panel.isFloatingPanel = true
        panel.level = .floating
        // Without this an AppKit panel is deallocated by its own close button
        // and the next ⌃⌥T uses a dangling reference.
        panel.isReleasedWhenClosed = false
        // Summoned onto whatever Space and full-screen app the user is in,
        // which is the behaviour the hotkey implies.
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: MenuBarConverterView())
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
