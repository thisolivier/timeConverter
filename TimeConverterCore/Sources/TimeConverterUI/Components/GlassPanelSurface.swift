import SwiftUI
#if os(macOS)
import AppKit
#endif

/// Where the glass panel is being drawn, which decides how much of its own
/// frosting it has to supply.
///
/// The three cases are not three styles — they are three *containers*, and the
/// panel looks the same in all of them. What differs is who provides the blur:
/// a window of our own has to make it, a system popover already has it, and an
/// offscreen rasteriser cannot have it at all.
public enum GlassPanelSurfaceStyle: String, Equatable, Sendable, CaseIterable {
    /// The summoned `NSPanel`: a transparent window floating over whatever the
    /// user was looking at. Supplies everything — behind-window material, rim
    /// stroke, inset highlights, rounded corners. The *shadow* is the one
    /// thing it deliberately does not draw; see `GlassPanelSurface`.
    case floatingWindow

    /// The `MenuBarExtra` dropdown. AppKit already drew a popover with its own
    /// material, its own corner radius and its own shadow, so a second set of
    /// all three would be a panel inside a panel. Only the ink is ours here.
    case hostedInSystemMaterial

    /// Previews and `ImageRenderer`. There is no window, so there is nothing
    /// to blur: the design's own 42% veil over a flat `Material` stands in, and
    /// the shadow is drawn by hand because no window is there to cast one.
    /// Honest about what it is — an approximation for judging layout and type,
    /// not for judging the glass.
    case offscreen
}

/// The panel's chrome: the frosting, the rim light, the two inset highlights
/// and the corner radius of page 3.
///
/// ## The mapping from the design's CSS, declaration by declaration
///
/// | design declaration | drawn by |
/// |---|---|
/// | `backdrop-filter: blur(44px) saturate(1.6)` | `NSVisualEffectView` material (`.hudWindow`) |
/// | `background: rgba(255,255,255,0.42)` | the same material — it is blur *and* tint |
/// | `border: 1px solid rgba(255,255,255,0.65)` | `GlassPalette.panelStroke`, hand-drawn |
/// | `border-radius: 30px` | `GlassPalette.panelCornerRadius`, hand-drawn |
/// | `inset 0 1px 0 rgba(255,255,255,0.9)` | `GlassPalette.panelTopHighlight`, hand-drawn |
/// | `inset 0 -1px 0 rgba(255,255,255,0.25)` | `GlassPalette.panelBottomHighlight`, hand-drawn |
/// | `box-shadow: 0 24px 70px rgba(0,0,0,0.28)` | the **window's** shadow (`NSWindow.hasShadow`) |
///
/// Two of those rows are the phase-B judgement calls, and both go the same way:
/// where the system has a real equivalent, the system wins.
///
/// **The frosting.** `NSVisualEffectView` with `.behindWindow` blending is the
/// only thing on macOS that samples the actual desktop behind a window —
/// a SwiftUI `Material` inside a hosted view blends with its own window, which
/// for a transparent window means blending with nothing. `.hudWindow` is the
/// material AppKit ships *for* floating utility panels, and it already carries
/// both halves of the CSS: the blur and a veil over it, tuned per appearance.
/// Laying the design's extra 42% white on top of a material that has its own
/// tint produced a milky panel you could not see through, which is the one
/// thing this design is not. So the veil is the material's, not ours, and
/// `GlassPalette.offscreenPanelTint` is named for the only place it still
/// applies.
///
/// **The shadow.** A transparent `NSWindow` with `hasShadow` casts a shadow
/// computed from its content's alpha, so a 30pt rounded panel gets a 30pt
/// rounded shadow for free — and gets the *system's* shadow, the one every
/// other floating panel on the desktop has. Drawing the design's `0 24px 70px`
/// by hand instead would have meant `.compositingGroup()`, which forces the
/// whole panel through an offscreen buffer and takes the behind-window
/// vibrancy with it. The hand-drawn shadow survives only in `.offscreen`,
/// where there is no window to ask.
///
/// Everything else the system has no opinion about — the rim light, the two
/// inset highlights, the 30pt radius — is transcribed literally.
public struct GlassPanelSurface: ViewModifier {
    private let style: GlassPanelSurfaceStyle

    public init(style: GlassPanelSurfaceStyle) {
        self.style = style
    }

    private var shape: RoundedRectangle {
        // `.continuous`, not `.circular`: at a 30pt radius the difference
        // between a squircle and a quarter-circle is the difference between a
        // Mac panel and a web card.
        RoundedRectangle(cornerRadius: GlassPalette.panelCornerRadius, style: .continuous)
    }

    public func body(content: Content) -> some View {
        switch style {
        case .hostedInSystemMaterial:
            // The popover is already glass. Adding our own would be a panel
            // inside a panel.
            content
        case .floatingWindow:
            framedPanel(content, frosting: AnyView(behindWindowFrosting))
        case .offscreen:
            framedPanel(content, frosting: AnyView(flatFrosting))
                .shadow(
                    color: GlassPalette.panelShadowColor,
                    radius: GlassPalette.panelShadowRadius,
                    x: 0,
                    y: GlassPalette.panelShadowOffsetY
                )
        }
    }

    /// Frosting, highlights, clip, rim — in that order, which is the order the
    /// CSS paints them and the only order that works: the highlights have to
    /// be inside the clip (a 1pt bar across the top of a 30pt rounded rect is
    /// mostly outside the shape, and the design's inset shadow is clipped by
    /// its own border-radius in exactly the same way), and the rim has to be
    /// outside it (`strokeBorder` on a clipped view loses its outer half).
    private func framedPanel(_ content: Content, frosting: AnyView) -> some View {
        content
            .background(frosting)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(GlassPalette.panelTopHighlight)
                    .frame(height: GlassPalette.hairlineThickness)
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(GlassPalette.panelBottomHighlight)
                    .frame(height: GlassPalette.hairlineThickness)
            }
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(
                    GlassPalette.panelStroke,
                    lineWidth: GlassPalette.hairlineThickness
                )
            }
    }

    /// The design's veil over a flat `Material`, for the contexts with no
    /// desktop to sample.
    private var flatFrosting: some View {
        GlassPalette.offscreenPanelTint.background(GlassPalette.panelMaterial)
    }

    @ViewBuilder
    private var behindWindowFrosting: some View {
        #if os(macOS)
        BehindWindowMaterial()
        #else
        // iOS has no behind-window anything — a view cannot see past its own
        // app. The glass design is Mac-only, so this branch exists to keep the
        // module cross-platform rather than because anyone draws it.
        flatFrosting
        #endif
    }
}

extension View {
    /// Dresses a view as the glass panel of page 3.
    public func glassPanelSurface(_ style: GlassPanelSurfaceStyle) -> some View {
        modifier(GlassPanelSurface(style: style))
    }
}

#if os(macOS)
/// `NSVisualEffectView`, blending with what is behind the *window*.
///
/// The second and last `#if os` in this module, and it earns its place the way
/// `PaletteTone`'s does: there is no cross-platform spelling of this, because
/// there is no cross-platform concept of it.
///
/// `.active` state rather than `.followsWindowActiveState`: the panel is
/// summoned by a hotkey from inside another app and spends much of its life
/// non-key, and a material that de-frosts when the window loses focus would
/// make the design flicker between two looks on every click. HUD panels on
/// this platform stay frosted.
private struct BehindWindowMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let effectView = NSVisualEffectView()
        effectView.material = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        // The corner is also masked by SwiftUI's `clipShape` one level up, but
        // a behind-window effect view draws into the window's backing store
        // rather than into SwiftUI's, and relying on a mask it does not
        // participate in is how square corners appear under a rounded panel.
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = GlassPalette.panelCornerRadius
        effectView.layer?.cornerCurve = .continuous
        effectView.layer?.masksToBounds = true
        return effectView
    }

    func updateNSView(_ effectView: NSVisualEffectView, context: Context) {
        effectView.layer?.cornerRadius = GlassPalette.panelCornerRadius
    }
}
#endif

/// The two 1pt rules of page 3: under the input line and above the footer.
///
/// A view rather than a `Rectangle` at every call site, because "the glass
/// design's rule is 1pt and `rgba(60, 60, 67, 0.3)`" is a design decision that
/// should exist once. The poster's equivalent is `PosterRule`, which is 2pt and
/// opaque — the two are deliberately not the same thing.
public struct GlassHairline: View {
    public init() {}

    public var body: some View {
        Rectangle()
            .fill(GlassPalette.hairline)
            .frame(height: GlassPalette.hairlineThickness)
            .accessibilityHidden(true)
    }
}
