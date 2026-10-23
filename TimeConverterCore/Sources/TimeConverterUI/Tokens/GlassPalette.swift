import SwiftUI

/// The colours and materials of the **glass** design — page 3 of
/// `docs/design/Time Converter-selection.pdf`, whose source markup is the
/// "Mac Liquid Glass panel" page inside `docs/design/Time Converter-2.html`.
///
/// ## Why this is a second palette and not a variant of the first
///
/// The poster palette is a *print*: opaque cream, opaque ink, one rust accent,
/// and it looks the same wherever it is put. The glass panel is the opposite
/// idea — it is a **system material over the user's desktop**, so its ink is
/// Apple's label greys (which are tuned to stay legible over an unknown
/// backdrop) and its one piece of colour, the arrow, is the same grey rather
/// than rust. There is nothing to inherit: the two designs disagree about every
/// token. Sharing `ConversionPairView` between them is possible precisely
/// *because* the colours are a parameter — see `ConversionPairStyle`.
///
/// The HTML also carries a second, cream-on-glass Mac mock. It is deliberately
/// not transcribed here: Olivier's direction (sprint plan, 2026-10-23) is that
/// the paper-style Mac variant is redundant and the native glass is the one to
/// build.
///
/// ## Light values are verbatim
///
/// Every `light:` value below is the design's own literal, unrounded:
///
/// | design declaration                           | token              |
/// |----------------------------------------------|--------------------|
/// | `background: rgba(255, 255, 255, 0.42)`       | `panelTint`        |
/// | `backdrop-filter: blur(44px) saturate(1.6)`   | `panelMaterial`    |
/// | `border: 1px solid rgba(255, 255, 255, 0.65)` | `panelStroke`      |
/// | `border-radius: 30px`                         | `panelCornerRadius`|
/// | `box-shadow: 0 24px 70px rgba(0,0,0,0.28)`    | `panelShadow*`     |
/// | `inset 0 1px 0 rgba(255,255,255,0.9)`         | `panelTopHighlight`|
/// | `inset 0 -1px 0 rgba(255,255,255,0.25)`       | `panelBottomHighlight` |
/// | `color: rgba(0, 0, 0, 0.88)`                  | `ink`              |
/// | `color: rgba(60, 60, 67, 0.78)`               | `secondaryInk`     |
/// | `color: rgba(60, 60, 67, 0.85)`               | `footerInk`        |
/// | `background: rgba(60, 60, 67, 0.3)` (1px)     | `hairline`         |
///
/// ## Dark values are derived, and here is the derivation
///
/// The design ships light only. `rgba(60, 60, 67, …)` is not an arbitrary grey
/// — it is Apple's light-appearance `secondaryLabel` tint — so the dark twins
/// keep the design's **alphas** and swap the tint to Apple's dark-appearance
/// one, `rgba(235, 235, 245, …)`. That is a transcription of the system's own
/// pairing rather than a new colour decision, which is the same discipline the
/// poster palette's inversion follows.
///
/// Three values could not be mirrored mechanically and are judgement calls,
/// flagged as such:
///
/// - `panelTint` cannot invert to "black at 0.42": a dark veil that heavy stops
///   being glass. `rgba(28, 28, 30, 0.45)` is the HUD-ish weight that still
///   shows the desktop through it.
/// - `ink` lifts from 0.88 to 0.92. White on a dark material at 0.88 reads
///   thinner than black on a light one at the same alpha, because the material
///   behind it is lighter than true black.
/// - `panelShadowColor` deepens from 0.28 to 0.45, since a 28% shadow is
///   invisible against a dark desktop.
///
/// Olivier verifies the glass on-device at the end of phase B; these three are
/// the values to look at first if it reads wrong at night.
public enum GlassPalette {
    // MARK: - The panel itself

    /// `backdrop-filter: blur(44px) saturate(1.6)`.
    ///
    /// A `Material` rather than a hand-rolled blur: the system materials are
    /// the only thing that actually samples the desktop behind a window, and
    /// `.regular` is the one whose blur and saturation boost land closest to
    /// the design's numbers. The tint below sits on top of it, exactly as the
    /// CSS layers its `background` over its `backdrop-filter`.
    public static let panelMaterial: Material = .regularMaterial

    /// The veil over the material. `rgba(255, 255, 255, 0.42)` in light.
    public static let panelTint = pairing(
        light: PaletteTone(red: 255, green: 255, blue: 255, alpha: 0.42),
        dark: PaletteTone(red: 28, green: 28, blue: 30, alpha: 0.45)
    )

    /// The 1pt rim light around the panel. `rgba(255, 255, 255, 0.65)`.
    public static let panelStroke = pairing(
        light: PaletteTone(red: 255, green: 255, blue: 255, alpha: 0.65),
        dark: PaletteTone(red: 255, green: 255, blue: 255, alpha: 0.18)
    )

    /// `inset 0 1px 0 rgba(255, 255, 255, 0.9)` — the bright top edge that
    /// makes the panel read as a lens rather than as a rectangle of fog.
    public static let panelTopHighlight = pairing(
        light: PaletteTone(red: 255, green: 255, blue: 255, alpha: 0.9),
        dark: PaletteTone(red: 255, green: 255, blue: 255, alpha: 0.22)
    )

    /// `inset 0 -1px 0 rgba(255, 255, 255, 0.25)` — the quieter bottom edge.
    public static let panelBottomHighlight = pairing(
        light: PaletteTone(red: 255, green: 255, blue: 255, alpha: 0.25),
        dark: PaletteTone(red: 255, green: 255, blue: 255, alpha: 0.08)
    )

    /// `border-radius: 30px`.
    public static let panelCornerRadius: CGFloat = 30

    /// `box-shadow: 0 24px 70px rgba(0, 0, 0, 0.28)`.
    public static let panelShadowColor = pairing(
        light: PaletteTone(red: 0, green: 0, blue: 0, alpha: 0.28),
        dark: PaletteTone(red: 0, green: 0, blue: 0, alpha: 0.45)
    )

    /// Half the CSS blur: a CSS shadow's blur radius spans the whole falloff,
    /// SwiftUI's is the standard deviation either side of the edge, so 70px of
    /// CSS is 35pt here. Getting this wrong by a factor of two is the usual way
    /// a transcribed shadow ends up looking like a smear.
    public static let panelShadowRadius: CGFloat = 35

    /// The `0 24px` of the same declaration.
    public static let panelShadowOffsetY: CGFloat = 24

    // MARK: - Ink on glass

    /// The big type and the typed input. `rgba(0, 0, 0, 0.88)`.
    public static let ink = pairing(
        light: PaletteTone(red: 0, green: 0, blue: 0, alpha: 0.88),
        dark: PaletteTone(red: 255, green: 255, blue: 255, alpha: 0.92)
    )

    /// The quiet furniture: `FROM` / `TO`, the sub-lines, and the arrow —
    /// which on glass is this grey and not rust. `rgba(60, 60, 67, 0.78)`.
    public static let secondaryInk = pairing(
        light: PaletteTone(red: 60, green: 60, blue: 67, alpha: 0.78),
        dark: PaletteTone(red: 235, green: 235, blue: 245, alpha: 0.78)
    )

    /// The footer sentence, a shade stronger than the furniture around it.
    /// `rgba(60, 60, 67, 0.85)`.
    public static let footerInk = pairing(
        light: PaletteTone(red: 60, green: 60, blue: 67, alpha: 0.85),
        dark: PaletteTone(red: 235, green: 235, blue: 245, alpha: 0.85)
    )

    /// The two 1px rules — under the input and above the footer.
    /// `rgba(60, 60, 67, 0.3)`.
    public static let hairline = pairing(
        light: PaletteTone(red: 60, green: 60, blue: 67, alpha: 0.3),
        dark: PaletteTone(red: 235, green: 235, blue: 245, alpha: 0.3)
    )

    /// The design's hairlines are declared `height: 1px`, not the poster's 2pt
    /// rules: on glass a heavy rule reads as a seam.
    public static let hairlineThickness: CGFloat = 1

    private static func pairing(light: PaletteTone, dark: PaletteTone) -> Color {
        AppearanceReactiveColor.pairing(light: light, dark: dark)
    }
}
