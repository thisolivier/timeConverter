import SwiftUI
import TimeConverterCore

/// The Mac converter UI — the dropdown's contents, and the summoned panel's.
///
/// **Visually plain on purpose.** `docs/ux-v1-proposal.md` has the Mac heading
/// for a translucent summoned modal with its own layout; that is a design
/// sprint. What this view proves is the restructure: the native shell drives
/// the *same* `ConverterDisplayDriver` as the iOS app, so the 600 ms prompt
/// debounce, the conversions and the tap-to-replace chips are all identical
/// behaviour from one core, with no forked model.
///
/// Logic-free, like its iOS counterpart: a `switch` over `ConverterDisplayState`
/// whose cases arrive fully rendered.
struct MenuBarConverterView: View {
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
        VStack(alignment: .leading, spacing: 12) {
            TextField("e.g. 12pm ET in London", text: $freeformInput)
                .textFieldStyle(.roundedBorder)
                .font(.title3)
                .autocorrectionDisabled()
                .focused($inputFieldIsFocused)
                // Submitting is an action, not typing, so it skips the debounce.
                .onSubmit { showResultWithoutWaiting() }

            outputArea

            Divider()

            // An app with no Dock icon and no windows has no other way out.
            Button("Quit Time Converter") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 400, alignment: .leading)
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

    @ViewBuilder
    private var outputArea: some View {
        switch displayDriver.displayState {
        case .hint:
            Text("Type a time to convert")
                .foregroundStyle(.secondary)

        case let .converted(display):
            VStack(alignment: .leading, spacing: 4) {
                Text(display.echoLine)
                    .font(.body)
                    .textSelection(.enabled)
                Text(display.detailLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        case let .problem(problem):
            VStack(alignment: .leading, spacing: 8) {
                Text(problem.message)
                    .font(.callout)
                    .foregroundStyle(.red)
                if !problem.chips.isEmpty {
                    // A horizontal scroller rather than the iOS shell's
                    // wrapping flow layout: placeholder styling, and the real
                    // Mac design decides this properly.
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(problem.chips) { chip in
                                Button(chip.label) { apply(chip) }
                                    .font(.callout)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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

#Preview {
    MenuBarConverterView()
}
