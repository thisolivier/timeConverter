// menubar-hotkey-collision.swift — does the system already own ⌃⌥T?
//
// Run via `swift scripts/menubar-hotkey-collision.swift` (scripts/qa-menubar.sh
// does). Exits 0 when ⌃⌥T is free of *enabled* system symbolic hotkeys, 1 when
// something owns it.
//
// Why this and not `defaults read com.apple.symbolichotkeys`: the plist holds
// only the entries the user has modified (19 on this machine), while
// `CopySymbolicHotKeys()` reports the real picture (229, 171 enabled). The
// difference is the whole reason the original ⌃⌥Space proposal was wrong —
// Space carries six registrations including ⌃⌥, which the plist does not show.
//
// The ⌃⌥T registration itself returning `noErr` proves nothing about this:
// symbolic hotkeys are consumed at a higher layer, so registering a combo the
// system owns *also* returns `noErr` and then silently never fires.

import Carbon.HIToolbox
import Foundation

var symbolicHotKeys: Unmanaged<CFArray>?
let copyStatus = CopySymbolicHotKeys(&symbolicHotKeys)
guard copyStatus == noErr,
      let entries = symbolicHotKeys?.takeRetainedValue() as? [[String: Any]] else {
    print("CopySymbolicHotKeys failed: \(copyStatus)")
    exit(1)
}

let targetKeyCode = Int(kVK_ANSI_T)
let targetModifiers = Int(controlKey | optionKey)  // 0x1800
let modifierMask = 0x1F00
let spaceKeyCode = 49  // the positive control, i.e. proof the method works

func keyCode(_ entry: [String: Any]) -> Int {
    entry[kHISymbolicHotKeyCode as String] as? Int ?? -1
}
func modifiers(_ entry: [String: Any]) -> Int {
    entry[kHISymbolicHotKeyModifiers as String] as? Int ?? -1
}
func isEnabled(_ entry: [String: Any]) -> Bool {
    entry[kHISymbolicHotKeyEnabled as String] as? Bool ?? false
}

let enabledCount = entries.filter(isEnabled).count
print("symbolic hotkeys: \(entries.count) total, \(enabledCount) enabled")

let collisions = entries.filter {
    keyCode($0) == targetKeyCode && modifiers($0) & modifierMask == targetModifiers && isEnabled($0)
}
let anyOnT = entries.filter { keyCode($0) == targetKeyCode }
print("on keycode \(targetKeyCode) (T): \(anyOnT.isEmpty ? "none" : "\(anyOnT.count) entries")")

// Printed every run: a "no collisions" result is only believable alongside
// evidence that the probe can see a combo that *is* taken.
let spaceEntries = entries.filter { keyCode($0) == spaceKeyCode }
let controlFound = spaceEntries.contains {
    modifiers($0) & modifierMask == targetModifiers && isEnabled($0)
}
print("control — keycode 49 (Space) carries \(spaceEntries.count) entries,"
    + " ⌃⌥Space enabled: \(controlFound ? "yes (as expected)" : "NO — probe may be broken")")

if collisions.isEmpty {
    print("RESULT: ⌃⌥T is free of enabled system symbolic hotkeys")
    exit(0)
}
for collision in collisions {
    print("RESULT: COLLISION — mods=0x\(String(modifiers(collision), radix: 16))")
}
exit(1)
