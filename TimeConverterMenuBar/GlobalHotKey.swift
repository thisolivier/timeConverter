import Carbon.HIToolbox

/// ⌃⌥T, registered with the WindowServer (backlog item 12a).
///
/// Carbon, because `RegisterEventHotKey` is the only route to a global hotkey
/// that needs **no permission at all**: the WindowServer delivers just the one
/// pre-declared chord, so the process never sees the keystream and there is
/// nothing for TCC to protect. The modern-looking alternatives — `CGEventTap`,
/// `NSEvent.addGlobalMonitorForEvents` — both require Input Monitoring and fail
/// by reporting success and then silently never firing.
///
/// The API is old but not deprecated in the current SDK, and is usable from
/// sandboxed App Store apps with no entitlement.
///
/// Main-actor-isolated throughout: the Carbon headers mark these calls "not
/// thread safe" (a background call still returns `noErr`, which is the trap)
/// and the press is delivered on the main thread regardless.
@MainActor
final class GlobalHotKey {
    /// What came of asking for the chord. None of these is fatal: the status
    /// item still works by click, so an unavailable hotkey is a log line.
    enum Registration: CustomStringConvertible {
        case registered
        /// `eventHotKeyExistsErr` — this process already asked, or another
        /// process holds ⌃⌥T *exclusively*. Notably this is what a second copy
        /// of the app launched with `open -n` sees, and it must shrug.
        case alreadyTaken
        case failed(OSStatus)

        var description: String {
            switch self {
            case .registered: "⌃⌥T"
            case .alreadyTaken: "no hotkey (⌃⌥T already taken — harmless)"
            case let .failed(status): "no hotkey (registration failed: \(status))"
            }
        }
    }

    /// `kVK_ANSI_T` identifies a **physical key position** on an ANSI US
    /// keyboard, not the letter printed on it: on a Dvorak layout the key
    /// labelled T is a different one. Fine to hardcode — but if the UI ever
    /// spells the shortcut out, it is naming a position.
    static let keyCode = UInt32(kVK_ANSI_T)

    /// Carbon modifier bitmask (`0x1800`), *not* `NSEvent.ModifierFlags`
    /// (where ⌃⌥ is `0x0C0000`). Mixing the two families is the classic bug in
    /// this corner of the OS, and silently registers the wrong chord.
    static let modifiers = UInt32(controlKey | optionKey)

    /// 'TCMB' — just has to be stable and ours.
    private static let signature: OSType = 0x5443_4D42
    private static let identifier: UInt32 = 1

    /// Main-actor-isolated: this ends up touching the status item's owner, and
    /// the press is delivered on the main thread anyway.
    private let onPress: @MainActor () -> Void
    private var hotKeyReference: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    init(onPress: @escaping @MainActor () -> Void) {
        self.onPress = onPress
    }

    func register() -> Registration {
        guard hotKeyReference == nil else { return .registered }

        // `GetEventDispatcherTarget()` for both calls — the root of the
        // propagation chain, and what the two established Swift hotkey
        // libraries use. The one hard rule is that the handler is installed on
        // the same target the hotkey is registered against.
        let eventTarget = GetEventDispatcherTarget()
        var hotKeyPressed = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)
        )
        var installedHandler: EventHandlerRef?
        let handlerStatus = InstallEventHandler(
            eventTarget,
            handleHotKeyEvent,
            1,
            &hotKeyPressed,
            Unmanaged.passUnretained(self).toOpaque(),
            &installedHandler
        )
        guard handlerStatus == noErr else { return .failed(handlerStatus) }
        eventHandler = installedHandler

        var registeredReference: EventHotKeyRef?
        let registrationStatus = RegisterEventHotKey(
            Self.keyCode,
            Self.modifiers,
            EventHotKeyID(signature: Self.signature, id: Self.identifier),
            eventTarget,
            0,
            &registeredReference
        )
        switch registrationStatus {
        case noErr:
            hotKeyReference = registeredReference
            return .registered
        case OSStatus(eventHotKeyExistsErr):
            return .alreadyTaken
        default:
            return .failed(registrationStatus)
        }
    }

    /// Idempotent. Not strictly required even on an orderly quit — the header
    /// says "you do not need to unregister a hot key when your application
    /// terminates; the system will take care of that for you", and a `kill -9`
    /// strands nothing — but tidying up is cheap.
    func unregister() {
        if let hotKeyReference {
            UnregisterEventHotKey(hotKeyReference)
            self.hotKeyReference = nil
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    /// Called from the C handler below.
    fileprivate func handlePress(matching pressedHotKey: EventHotKeyID) {
        guard pressedHotKey.signature == Self.signature,
              pressedHotKey.id == Self.identifier else { return }
        onPress()
    }
}

/// The Carbon callback. A free function so it converts to a `@convention(c)`
/// function pointer; the instance travels as `userData` rather than in a
/// capture, which a C function pointer cannot have.
private func handleHotKeyEvent(
    _ callRef: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }

    // The handler sits on the dispatcher target, which sees every hotkey event
    // in the process, so read which one fired rather than assuming.
    var pressedHotKey = EventHotKeyID()
    let parameterStatus = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &pressedHotKey
    )
    guard parameterStatus == noErr else { return OSStatus(eventNotHandledErr) }

    // `assumeIsolated` rather than a hop: hotkey events are pulled off the
    // application's own main-thread event loop, so asserting that invariant is
    // better than pretending the callback might arrive anywhere.
    let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
    MainActor.assumeIsolated { hotKey.handlePress(matching: pressedHotKey) }
    return noErr
}
