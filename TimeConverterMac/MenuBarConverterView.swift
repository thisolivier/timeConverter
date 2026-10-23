import SwiftUI
import TimeConverterCore
import TimeConverterUI

/// The Mac converter — the summoned panel's contents, and the dropdown's.
///
/// Everything visible is `GlassConverterLayout` (page 3 of
/// `docs/design/Time Converter-selection.pdf`). What lives here instead is the
/// state that layout refuses to own: the typed sentence, the display driver
/// that debounces it, and the focus choreography of backlog item 17.
///
/// One view for both containers, parameterised by `GlassPresentation` — which
/// is working assumption 3 of the sprint plan made structural. The dropdown is
/// not a second design; it is this design at 400pt, and the only reason it
/// looks different is that the conversion pair does not fit side by side there
/// and says so for itself.
///
/// Logic-free below the state: `GlassResultSection.routing` turns the display
/// state into what the panel shows, and the layout draws it.
struct MenuBarConverterView: View {
    var presentation: GlassPresentation = .menuBarDropdown

    @State private var freeformInput: String = LaunchArguments.initialInput ?? ""
    @State private var displayDriver = ConverterDisplayDriver()
    @FocusState private var inputFieldIsFocused: Bool

    /// Item 17's two triggers, between them covering both ways the Mac UI can
    /// arrive.
    ///
    /// `controlActiveState` is the general one: it turns `.key` the moment this
    /// view's window takes the keyboard, which happens for the `MenuBarExtra`
    /// dropdown and for the summoned panel alike, and happens again every time
    /// the panel is re-raised. `summonFocusRequests` is the specific one, for
    /// the press that reaches a panel which is *already* key — no window state
    /// changes there, so nothing else would fire.
    @Environment(\.controlActiveState) private var controlActiveState
    @State private var summonFocusRequests = SummonFocusRequests.shared

    var body: some View {
        GlassConverterLayout(
            presentation: presentation,
            section: GlassResultSection.routing(for: displayDriver.displayState),
            onChipTap: apply
        ) {
            GlassInputField(
                text: $freeformInput,
                metrics: presentation.metrics,
                onSubmit: showResultWithoutWaiting
            )
            .focused($inputFieldIsFocused)
        }
        .onChange(of: freeformInput) {
            displayDriver.inputDidChange(
                to: freeformInput, now: Date(), localZone: TimeZone.current
            )
        }
        .onAppear {
            // The dropdown and the panel are both "arrival": for a typed-input
            // tool, landing ready to type *is* the access story.
            showResultWithoutWaiting()
            focusTheFieldAsSoonAsTheWindowWillAllowIt()
        }
        // A window that has just been ordered front becomes key *after* the
        // hosting view appears, so `onAppear` alone was landing the focus write
        // too early — the complaint behind item 17.
        .onChange(of: controlActiveState) { _, state in
            guard state == .key else { return }
            focusTheFieldAsSoonAsTheWindowWillAllowIt()
        }
        // ⌃⌥T aimed at a panel that is already key: no window state changes, so
        // the summoner says so directly.
        .onChange(of: summonFocusRequests.requestCount) {
            focusTheFieldAsSoonAsTheWindowWillAllowIt()
        }
    }

    /// Writes `@FocusState` repeatedly over a short, bounded ladder.
    ///
    /// One write is not enough and cannot be made enough from here: whether it
    /// takes depends on how far AppKit has got with making the window key and
    /// how far SwiftUI has got with installing its responder chain, and the
    /// view has no way to observe either. The rungs and the reasoning live in
    /// `SummonFocusLadder`; a rung that fires after focus already landed
    /// assigns `true` to something already `true` and does nothing.
    private func focusTheFieldAsSoonAsTheWindowWillAllowIt() {
        for delay in SummonFocusLadder.attemptDelays {
            if delay == .zero {
                inputFieldIsFocused = true
                continue
            }
            Task { @MainActor in
                try? await Task.sleep(for: delay)
                inputFieldIsFocused = true
            }
        }
    }

    /// `Date()` and `TimeZone.current` live in the view and nowhere else, so
    /// the core stays pure — the same contract the iOS shell honours.
    private func showResultWithoutWaiting() {
        displayDriver.showWithoutWaiting(
            for: freeformInput, now: Date(), localZone: TimeZone.current
        )
    }

    /// A chip rewrites the sentence; the sentence stays the single source of
    /// truth and the re-parse follows from it.
    private func apply(_ chip: ReplacementChip) {
        freeformInput = displayDriver.apply(
            chip, to: freeformInput, now: Date(), localZone: TimeZone.current
        )
    }
}

// MARK: - Previews

/// The panel over a stand-in desktop, because a material previewed against
/// nothing looks like nothing. Both appearances, because the glass tokens'
/// dark values are derived rather than designed and this is where they get
/// looked at.
private struct GlassPanelPreview: View {
    let presentation: GlassPresentation

    var body: some View {
        MenuBarConverterView(presentation: presentation)
            .padding(60)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.31, green: 0.43, blue: 0.62),
                        Color(red: 0.13, green: 0.22, blue: 0.37)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
}

#Preview("Panel — light") {
    GlassPanelPreview(presentation: .summonedPanel)
}

#Preview("Panel — dark") {
    GlassPanelPreview(presentation: .summonedPanel)
        .preferredColorScheme(.dark)
}

#Preview("Dropdown — light") {
    GlassPanelPreview(presentation: .menuBarDropdown)
}

#Preview("Dropdown — dark") {
    GlassPanelPreview(presentation: .menuBarDropdown)
        .preferredColorScheme(.dark)
}
