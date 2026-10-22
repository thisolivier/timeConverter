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
            inputFieldIsFocused = true
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
