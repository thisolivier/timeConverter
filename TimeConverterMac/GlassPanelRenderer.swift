#if DEBUG
import AppKit
import SwiftUI
import TimeConverterCore
import TimeConverterUI

/// QA affordance: `-renderGlass <directory>` draws the glass panel into PNGs
/// and quits.
///
/// It exists because screenshotting a Mac app on this machine is blocked —
/// screen capture needs TCC consent a headless session cannot give — and the
/// glass panel is the first thing this project has built that is *entirely* a
/// design. "The tests pass" says nothing about whether the composition is the
/// composition. `ImageRenderer` is the one route to a picture of a SwiftUI view
/// that needs no window server consent, so this walks the states the design
/// does and does not draw, in both appearances, and writes them out.
///
/// ## What these pictures are and are not
///
/// They are the **layout and the type**: the 740pt proportion, the hairlines,
/// the 124pt numerals against the 12pt labels, the chips wrapping, the stacked
/// fallback, and whether light and dark ink both carry.
///
/// They are **not the glass**. `ImageRenderer` rasterises offscreen, and an
/// offscreen pass has no window and therefore no desktop to blur: a
/// behind-window `NSVisualEffectView` draws nothing at all there, and even a
/// SwiftUI `Material` flattens to an approximation. That is why the renderer
/// forces `GlassPanelSurfaceStyle.offscreen`, which substitutes the design's
/// own 42% veil so there is something for the ink to sit on. The frosting,
/// the saturation and the shadow can only be judged on a real desktop — which
/// is what `scripts/run-mac.sh` and Olivier's eyes are for.
@MainActor
enum GlassPanelRenderer {
    static let key = "renderGlass"

    /// Renders and terminates, or does nothing at all. Called from
    /// `applicationDidFinishLaunching` before the summoner starts, so a render
    /// run never registers ⌃⌥T or puts a status item in the menu bar.
    static func runIfRequested() {
        guard let directory = UserDefaults.standard.string(forKey: key),
              !directory.isEmpty
        else { return }
        render(into: URL(fileURLWithPath: directory))
        NSApp.terminate(nil)
    }

    /// Every case worth looking at: the one the design draws, the two it does
    /// not, and the narrow container — each in both appearances.
    private static var cases: [(name: String, presentation: GlassPresentation, input: String)] {
        [
            ("panel-converted", .summonedPanel, "8pm Lisbon in Sao Paulo"),
            ("panel-hint", .summonedPanel, ""),
            ("panel-prompt-chips", .summonedPanel, "8pm Lisbon in Lundon"),
            ("panel-prompt-plain", .summonedPanel, "hello there"),
            ("dropdown-converted", .menuBarDropdown, "8pm Lisbon in Sao Paulo"),
            ("dropdown-prompt-chips", .menuBarDropdown, "8pm Lisbon in Lundon")
        ]
    }

    private static func render(into directory: URL) {
        try? FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true
        )

        for appearanceName in [NSAppearance.Name.aqua, .darkAqua] {
            let label = appearanceName == .darkAqua ? "dark" : "light"
            guard let appearance = NSAppearance(named: appearanceName) else { continue }

            for renderCase in cases {
                // The palette's colours are dynamic `NSColor`s, so they resolve
                // against the *drawing* appearance rather than against SwiftUI's
                // environment. Both are set: the block for the palette, the
                // environment for anything SwiftUI tints itself.
                appearance.performAsCurrentDrawingAppearance {
                    write(
                        renderCase: renderCase,
                        colorScheme: appearanceName == .darkAqua ? .dark : .light,
                        to: directory.appendingPathComponent(
                            "phaseB-\(renderCase.name)-\(label).png"
                        )
                    )
                }
            }
        }
    }

    private static func write(
        renderCase: (name: String, presentation: GlassPresentation, input: String),
        colorScheme: ColorScheme,
        to url: URL
    ) {
        let driver = ConverterDisplayDriver()
        driver.showWithoutWaiting(
            for: renderCase.input, now: Date(), localZone: TimeZone.current
        )

        let panel = GlassConverterLayout(
            presentation: renderCase.presentation,
            section: GlassResultSection.routing(for: driver.displayState),
            surfaceStyle: .offscreen,
            onChipTap: { _ in }
        ) {
            // Not the live `GlassInputField`: `ImageRenderer` cannot rasterise
            // a `TextField` and draws SwiftUI's yellow "unsupported" bar in its
            // place. `GlassInputEcho` is the same line without the control —
            // same font, same size, same ink, via the same modifier.
            GlassInputEcho(
                text: renderCase.input, metrics: renderCase.presentation.metrics
            )
        }

        let renderer = ImageRenderer(
            content: panel
                .padding(60)
                .background(desktopStandIn)
                .environment(\.colorScheme, colorScheme)
        )
        // Retina, so the compressed numerals can be judged rather than guessed
        // at.
        renderer.scale = 2

        guard let image = renderer.cgImage else { return }
        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { return }
        try? data.write(to: url)
    }

    /// Stands in for the desktop a real panel floats over. A translucent panel
    /// photographed against white is a white rectangle, which says nothing
    /// about anything.
    private static var desktopStandIn: some View {
        LinearGradient(
            colors: [
                Color(red: 0.31, green: 0.43, blue: 0.62),
                Color(red: 0.13, green: 0.22, blue: 0.37)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
#endif
