import CoreGraphics

/// The glass panel's **dimensions**, transcribed from the same markup
/// `GlassPalette` takes its colours from — the "Mac Liquid Glass panel" page of
/// `docs/design/Time Converter-2.html`, drawn as page 3 of the PDF.
///
/// Colours live next door in `GlassPalette`; this is everything measured in
/// points. They are separate files because they fail differently: a wrong
/// colour is a judgement call about a material, a wrong measurement is a
/// transcription error you can check against the stylesheet with a ruler.
///
/// ## The design's own declarations
///
/// | design declaration                 | token                  |
/// |------------------------------------|------------------------|
/// | `width: 740px`                     | `totalWidth` (`.wide`) |
/// | `padding: 26px 30px 26px`          | `verticalPadding` / `horizontalPadding` |
/// | `gap: 22px` (the section flow)     | `sectionSpacing`       |
/// | input block `gap: 14px`            | `inputRuleSpacing`     |
/// | input block `padding: 6px 4px 0`   | `inputTopPadding` / `inputLeadingPadding` |
/// | input `font-size: 34px`            | `inputFontSize`        |
/// | caret `width: 2px; height: 38px`   | `caretWidth` / `caretHeight` |
/// | footer block `gap: 10px`           | `footerRuleSpacing`    |
/// | footer `font-size: 15px`           | `footerFontSize`       |
///
/// The caret tokens are transcribed but unused: the design draws a *fake*
/// blinking caret because its input is a static mock, and a real `TextField`
/// brings the system's own. They are kept so the next reader can see that the
/// omission was a decision rather than an oversight.
///
/// ## The narrow variant is derived, not designed
///
/// The design ships one width. `MenuBarExtra`'s dropdown is nowhere near 740pt
/// — it is a menu-bar popover, and one that wide would be absurd — so `.narrow`
/// is this module's own derivation, which is working assumption 3 of
/// `docs/sprint-plan-ipad-mac.md` ("the dropdown gets the same content adapted
/// to its width"). Its paddings step down proportionally, and its input type
/// steps down to a size that still reads as the design's oversized mono line
/// rather than as a form field.
///
/// What it does **not** do is pick a layout by hand: `pairAxis` and `pairScale`
/// are computed from the content width by `ConversionPairScale`'s own fitting
/// arithmetic, so the dropdown stacks because the pair genuinely does not fit,
/// and would un-stack by itself if it ever did.
public struct GlassPanelMetrics: Sendable, Equatable {
    /// The panel's outside width. Fixed, not user-resizable — working
    /// assumption 3: this is a composition at a fixed internal proportion, and
    /// a resizable glass panel would be a different design.
    public let totalWidth: CGFloat
    /// `padding: … 30px`.
    public let horizontalPadding: CGFloat
    /// `padding: 26px …`.
    public let verticalPadding: CGFloat
    /// The `gap: 22px` between the three sections: input, pair, footer.
    public let sectionSpacing: CGFloat
    /// The input block's own `gap: 14px`, between the typed line and its rule.
    public let inputRuleSpacing: CGFloat
    /// The input block's `padding: 6px 4px 0` — a small optical inset that
    /// stops the oversized mono line from touching the panel's padding box.
    public let inputTopPadding: CGFloat
    public let inputLeadingPadding: CGFloat
    /// `font-size: 34px` on the typed line. The single largest piece of mono
    /// type in the app, and the reason the panel reads as a command line.
    public let inputFontSize: CGFloat
    /// The footer block's `gap: 10px`, between its rule and the sentence.
    public let footerRuleSpacing: CGFloat
    /// `font-size: 15px` on the footer sentence.
    public let footerFontSize: CGFloat

    /// The design's blinking caret. Transcribed, deliberately unused — see the
    /// type's documentation.
    public static let caretWidth: CGFloat = 2
    public static let caretHeight: CGFloat = 38

    /// Page 3, verbatim.
    public static let wide = GlassPanelMetrics(
        totalWidth: 740,
        horizontalPadding: 30,
        verticalPadding: 26,
        sectionSpacing: 22,
        inputRuleSpacing: 14,
        inputTopPadding: 6,
        inputLeadingPadding: 4,
        inputFontSize: 34,
        footerRuleSpacing: 10,
        footerFontSize: 15
    )

    /// The `MenuBarExtra` dropdown. Derived; see the type's documentation.
    ///
    /// 400pt is the width the Mac shell's placeholder dropdown already used and
    /// is about as wide as a menu-bar popover can be without looking like a
    /// window that lost its title bar. Everything else is the wide metrics
    /// stepped down by roughly the same ratio the pair's `.compact` step uses,
    /// except the input, which comes down harder: 34pt mono in a 364pt content
    /// box fits ten characters, and `8pm Lisbon in São Paulo` is twenty-three.
    public static let narrow = GlassPanelMetrics(
        totalWidth: 400,
        horizontalPadding: 18,
        verticalPadding: 16,
        sectionSpacing: 16,
        inputRuleSpacing: 10,
        inputTopPadding: 4,
        inputLeadingPadding: 2,
        inputFontSize: 20,
        footerRuleSpacing: 8,
        footerFontSize: 13
    )

    /// The space actually available to the pair, the input and the footer.
    public var contentWidth: CGFloat { totalWidth - horizontalPadding * 2 }

    /// The largest size step whose side-by-side pair fits the content width,
    /// or `.compact` when neither does and the pair has to stack.
    public var pairScale: ConversionPairScale {
        ConversionPairScale.largestFittingSideBySide(in: contentWidth) ?? .compact
    }

    /// Side by side when there is room for two columns and the design's
    /// gutter; stacked when there is not.
    ///
    /// Computed rather than stored, so "the dropdown stacks" is a *consequence*
    /// of 400pt rather than a second fact that could disagree with it.
    public var pairAxis: ConversionPairAxis {
        ConversionPairScale.largestFittingSideBySide(in: contentWidth) == nil
            ? .stacked
            : .sideBySide
    }
}
