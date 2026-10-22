import AppKit

/// The bundle's `NSPrincipalClass`: one status item, one global hotkey, one
/// callback into the app (backlog item 12a).
///
/// This class is compiled against the **macOS** SDK and loaded into a Mac
/// Catalyst process at runtime, which is the only way to reach `NSStatusItem`
/// and Carbon from this app at all. Two consequences worth remembering while
/// editing it:
///
/// - `@available` and `#available` are meaningless-to-misleading here: this is
///   a macOS-platform binary, so iOS version predicates do not mean what they
///   look like. Don't use them.
/// - Everything runs on the main thread. `NSStatusItem` requires it, the Carbon
///   APIs are documented "not thread safe", and the hotkey handler is delivered
///   there regardless.
@MainActor
@objc(MenuBarController)
public final class MenuBarController: NSObject, MenuBarHosting {
    /// Required, `@objc`, and `override`: the app instantiates this
    /// reflectively from `NSPrincipalClass` through `NSObject.Type.init()`.
    @objc public required override init() { super.init() }

    private var statusItem: NSStatusItem?
    private var hotKey: GlobalHotKey?
    private var onSummon: (() -> Void)?

    @objc public func start(onSummon: @escaping () -> Void) -> String {
        self.onSummon = onSummon
        let statusItemSummary = addStatusItem()
        let hotKey = GlobalHotKey { [weak self] in self?.summon() }
        self.hotKey = hotKey
        // Both halves report what *actually* came up rather than what was
        // asked for, because this string is the only evidence the QA script
        // has: a hardcoded "status item" would make its assertion a
        // tautology. Neither half can fail the launch — a second instance of
        // the app, or another app holding ⌃⌥T exclusively, must not stop the
        // menu bar from working by click, and vice versa.
        return "\(statusItemSummary) + \(hotKey.register().description)"
    }

    @objc public func stop() {
        hotKey?.unregister()
        hotKey = nil
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
        onSummon = nil
    }

    /// Returns what came up, for the log — see `start`.
    private func addStatusItem() -> String {
        guard statusItem == nil else { return "status item" }
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.statusItem = statusItem

        guard let button = statusItem.button else {
            return "no status item (NSStatusBar returned no button)"
        }
        // A clock glyph, template-rendered so it tracks the menu bar's
        // light/dark appearance. The letter is a fallback for the
        // impossible-but-cheap case of the symbol being unavailable: an
        // invisible status item is indistinguishable from a broken one.
        button.image = NSImage(
            systemSymbolName: "clock", accessibilityDescription: "TimeConverter"
        )
        button.image?.isTemplate = true
        if button.image == nil { button.title = "T" }
        button.toolTip = "TimeConverter — ⌃⌥T"
        button.target = self
        button.action = #selector(statusItemClicked)

        // `button.window` is the status bar's own window: non-nil means AppKit
        // has actually placed the item, which is as close to "it is on screen"
        // as anything headless can get. Reported, never fatal — a menu bar
        // that failed to appear still must not cost the user their app.
        guard button.window != nil, statusItem.isVisible else {
            return "status item (created but not placed in the menu bar)"
        }
        return "status item"
    }

    @objc private func statusItemClicked() { summon() }

    /// Bring the app forward, then let the app decide what to do with the
    /// window it just got back.
    ///
    /// Activation has to happen on this side: Catalyst has no API for an app to
    /// raise itself, while `NSApplication` here is the real, live application
    /// object of this very process.
    private func summon() {
        let application = NSApplication.shared
        application.activate(ignoringOtherApps: true)
        // Catalyst scenes are ordinary AppKit windows underneath. Raising the
        // first one that can take key status covers the common single-window
        // case without second-guessing a user who opened more.
        if let window = application.windows.first(where: { $0.canBecomeKey }) {
            window.makeKeyAndOrderFront(nil)
        }
        onSummon?()
    }
}
