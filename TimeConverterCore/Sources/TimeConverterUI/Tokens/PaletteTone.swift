import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// One literal colour value out of a design file, before it is paired with its
/// opposite-appearance twin.
///
/// Written as components rather than as a `Color` because a `Color` cannot be
/// asked what it is made of, and every token in this module has to survive the
/// round trip from a CSS or SVG literal (`rgba(60, 60, 67, 0.78)`,
/// `#EBD3A9`) into something a reviewer can check against the design by eye.
/// The two initialisers below are exactly the two shapes the designs hand the
/// values over in.
struct PaletteTone: Sendable, Equatable {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat

    /// `0xEB_D3_A9` → the colour. Packed because that is how the paper poster
    /// writes its tokens, and a transcription error in a hex literal is easier
    /// to spot than one in three decimal fractions.
    init(packedRGB: UInt32, alpha: CGFloat = 1) {
        self.red = CGFloat((packedRGB >> 16) & 0xFF) / 255
        self.green = CGFloat((packedRGB >> 8) & 0xFF) / 255
        self.blue = CGFloat(packedRGB & 0xFF) / 255
        self.alpha = alpha
    }

    /// `rgba(60, 60, 67, 0.78)` → the colour, in the 0–255 channel values the
    /// glass design writes. Kept in CSS units rather than normalised here so
    /// the call sites read as the stylesheet does.
    init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        self.red = red / 255
        self.green = green / 255
        self.blue = blue / 255
        self.alpha = alpha
    }
}

/// Pairs two tones into one appearance-reactive `Color`.
///
/// The iOS poster palette used to do this with a bare `UIColor` dynamic
/// provider. That could not move into a module the Mac also links, so the
/// provider is written once here against both platform colour types — the
/// *only* `#if os` in this module, deliberately, because every other difference
/// between the two shells is a layout decision rather than a platform one.
///
/// A dynamic platform colour rather than an `@Environment(\.colorScheme)` read:
/// the palettes are `static let`s with no view to read an environment from, and
/// this way previews, the system setting and a mid-session appearance change
/// all resolve correctly with no view state at all.
enum AppearanceReactiveColor {
    static func pairing(light: PaletteTone, dark: PaletteTone) -> Color {
        #if canImport(UIKit)
        return Color(UIColor { traits in
            platformColor(for: traits.userInterfaceStyle == .dark ? dark : light)
        })
        #elseif canImport(AppKit)
        return Color(NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return platformColor(for: isDark ? dark : light)
        })
        #endif
    }

    #if canImport(UIKit)
    private static func platformColor(for tone: PaletteTone) -> UIColor {
        UIColor(red: tone.red, green: tone.green, blue: tone.blue, alpha: tone.alpha)
    }
    #elseif canImport(AppKit)
    private static func platformColor(for tone: PaletteTone) -> NSColor {
        NSColor(
            srgbRed: tone.red, green: tone.green, blue: tone.blue, alpha: tone.alpha
        )
    }
    #endif
}
