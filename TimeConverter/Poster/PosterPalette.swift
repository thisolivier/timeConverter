import SwiftUI

/// The colours of the retro-poster design (`docs/design/Time Converter.{pdf,html}`).
///
/// Three tokens, taken verbatim from the design's own inline styles: cream
/// `#EBD3A9`, ink `#141210`, rust `#B5391F`. Everything on screen is one of
/// these, which is what makes the thing read as a printed poster rather than as
/// an app wearing a palette.
///
/// ## Dark mode
///
/// The design ships one mode. The dark variant is a **straight inversion** —
/// the ink becomes the paper and the cream becomes the ink — rather than a new
/// palette, so the poster stays the same poster at night. Two adjustments were
/// needed, both for contrast rather than for taste:
///
/// - The rust **accent** (the arrow, the caret) is lifted to `#E0633F` in dark
///   mode. `#B5391F` on `#141210` is 2.4:1 and effectively disappears; the
///   lifted tone is 5.4:1 against the dark paper.
/// - The rust used for **prompt text on cream** is deepened to `#9E3019`.
///   `#B5391F` on `#EBD3A9` is 4.04:1, which is under AA for body-sized text;
///   the deepened tone is 4.99:1 and is indistinguishable from the accent at a
///   glance. The accent itself is untouched, because a 5pt arrow stroke is not
///   body text.
///
/// Everything here is a dynamic `UIColor`, so previews, the system setting and
/// a mid-session appearance change all resolve correctly with no view state.
enum PosterPalette {
    /// The paper. Cream in light, ink in dark.
    static let paper = dynamic(light: 0xEB_D3_A9, dark: 0x14_12_10)

    /// Everything printed on the paper: type, rules, the input box's border.
    static let ink = dynamic(light: 0x14_12_10, dark: 0xEB_D3_A9)

    /// The one accent: the separator arrow and the text caret.
    static let accent = dynamic(light: 0xB5_39_1F, dark: 0xE0_63_3F)

    /// The accent at text weight — prompts, did-you-mean copy, the
    /// daylight-saving note. Same hue, legible at 14pt.
    static let accentText = dynamic(light: 0x9E_30_19, dark: 0xE0_63_3F)

    /// Ink at reading-but-quiet strength: the hint, the field's placeholder.
    /// An opacity rather than a fourth colour, so it tracks both modes for
    /// free.
    static let quietInk = ink.opacity(0.55)

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            UIColor(packedRGB: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    /// `0xEB_D3_A9` → the colour. Written as a packed integer because that is
    /// how the design hands the tokens over, and a transcription error in a hex
    /// literal is easier to spot than one in three decimal fractions.
    convenience init(packedRGB: UInt32) {
        self.init(
            red: CGFloat((packedRGB >> 16) & 0xFF) / 255,
            green: CGFloat((packedRGB >> 8) & 0xFF) / 255,
            blue: CGFloat(packedRGB & 0xFF) / 255,
            alpha: 1
        )
    }
}
