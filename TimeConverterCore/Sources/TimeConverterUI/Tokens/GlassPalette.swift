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
/// | `background: rgba(255, 255, 255, 0.42)`       | *the system material* (`offscreenPanelTint` off screen) |
/// | `backdrop-filter: blur(44px) saturate(1.6)`   | *the system material* (`panelMaterial` off window) |
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
/// - `offscreenPanelTint` cannot invert to "black at 0.42": a dark veil that
///   heavy stops being glass. `rgba(28, 28, 30, 0.45)` is the HUD-ish weight
///   that still shows the desktop through it.
/// - `ink` lifts from 0.88 to 0.92. White on a dark material at 0.88 reads
///   thinner than black on a light one at the same alpha, because the material
///   behind it is lighter than true black.
/// - `panelShadowColor` deepens from 0.28 to 0.45, since a 28% shadow is
///   invisible against a dark desktop.
///
/// Olivier verifies the glass on-device at the end of phase B; these three are
/// the values to look at first if it reads wrong at night.
///
/// ## Phase B: the blur and the veil are one system material, not two layers
///
/// The CSS declares the frosting in two parts — a `backdrop-filter` that blurs
/// and saturates, and a white `background` laid over it — because that is the
/// only shape the web gives you: `backdrop-filter` has no tint of its own.
///
/// AppKit's materials are not built that way. An `NSVisualEffectView` *is* blur
/// plus tint plus saturation, tuned together per material and per appearance,
/// and it is also the only thing on the platform that genuinely samples the
/// desktop behind a window. So phase B maps **both** declarations onto one
/// `.hudWindow` behind-window material (see `GlassPanelSurface`) rather than
/// stacking the design's 42% white on top of a material that already carries a
/// veil — which would have produced a milky panel you could not see through,
/// the one thing the design is not.
///
/// What the system material does *not* supply, and what therefore stays here as
/// real tokens, is everything outside the frosting: the rim stroke, the two
/// inset highlights, the shadow, the corner radius and every ink.
public enum GlassPalette {
    // MARK: - The panel itself

    /// The design's veil, kept for the two places that have no desktop to
    /// sample: SwiftUI previews and `ImageRenderer`'s offscreen rasteriser.
    /// Both draw a `Material` as a flat approximation, so without this the
    /// panel renders as plain grey and nothing about the composition can be
    /// judged. `rgba(255, 255, 255, 0.42)` in light.
    ///
    /// Named for where it is allowed to be used. On screen the material is the
    /// tint — see the note above.
    public static let offscreenPanelTint = pairing(
        light: PaletteTone(red: 255, green: 255, blue: 255, alpha: 0.42),
        dark: PaletteTone(red: 28, green: 28, blue: 30, alpha: 0.45)
    )

    // MARK: - Prompts and chips, which the design does not draw

    /// The small letterspaced caption over a prompt — `CAN'T CONVERT YET`.
    ///
    /// The iPhone sets this pair, caption and message, in rust. Glass has no
    /// rust: the one colour decision page 3 makes is that the arrow is grey
    /// rather than the poster's accent, and introducing a second accent for
    /// the error state would undo it. So the glass prompt builds its emphasis
    /// the way the rest of the panel does — out of contrast. The caption is
    /// quiet furniture and the message below it is full-strength ink, which
    /// inverts the poster's relationship and is correct here: on a material,
    /// weight reads and hue does not.
    public static let promptCaptionInk = secondaryInk

    /// The prompt sentence itself. Full-strength ink, because it is the only
    /// thing on the panel worth reading when it is showing.
    public static let promptMessageInk = ink

    /// A tap-to-replace chip's fill. The design draws no chips — it only draws
    /// the happy path — so these three are this module's own, derived from the
    /// greys already in the palette rather than invented: the same
    /// `rgba(60, 60, 67, …)` / `rgba(235, 235, 245, …)` pairing as every other
    /// token here, at the low alphas a control sitting *on* a material wants.
    public static let chipFill = pairing(
        light: PaletteTone(red: 255, green: 255, blue: 255, alpha: 0.45),
        dark: PaletteTone(red: 255, green: 255, blue: 255, alpha: 0.12)
    )

    /// Held down. Strong enough to be unmistakable on a translucent surface,
    /// where a 10% change in fill is invisible.
    public static let chipPressedFill = pairing(
        light: PaletteTone(red: 255, green: 255, blue: 255, alpha: 0.85),
        dark: PaletteTone(red: 255, green: 255, blue: 255, alpha: 0.3)
    )

    /// The chip's outline, at the same alpha as the panel's own hairlines so
    /// the chips read as part of the same drawing.
    public static let chipStroke = hairline

    /// Chips are rounded where the panel is rounded, scaled down to a control.
    /// Square — the poster's chip shape — would read as a dialog button
    /// dropped onto a Mac panel.
    public static let chipCornerRadius: CGFloat = 8

    // MARK: - The panel's frosting, where no window can supply it

    /// `backdrop-filter: blur(44px) saturate(1.6)`, for the contexts that have
    /// no `NSWindow` to hang a behind-window effect view on.
    ///
    /// On screen the Mac panel uses `NSVisualEffectView` directly
    /// (`GlassPanelSurface`), because a SwiftUI `Material` inside a hosted view
    /// blends with its *window*, and the whole point of this design is that it
    /// blends with the user's desktop. This is the fallback the same surface
    /// falls back to elsewhere, and what previews and `ImageRenderer` get.
    ///
    /// `.regular` is the step whose blur and saturation boost land closest to
    /// the design's numbers; `.ultraThin` is too transparent to carry ink at
    /// this scale and `.thick` stops showing the desktop at all.
    public static let panelMaterial: Material = .regularMaterial

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
