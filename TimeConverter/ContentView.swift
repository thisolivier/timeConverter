import SwiftUI
import TimeConverterCore

/// The whole iOS app, laid out as the poster in `docs/design/Time
/// Converter.pdf`: title, rule, labelled input box with the parsed source
/// echoed *inside* it, the rule-and-arrow band, and the result at poster scale
/// over its footer sentence.
///
/// Still logic-free. Every string on screen arrives pre-rendered from
/// `TimeConverterCore` — including, new in item 18, the decomposed result
/// fields the layout needs. What the view owns, and could not delegate, is
/// platform state: keyboard focus, the scene phase, the typed string itself.
/// Timing lives in `ConverterDisplayDriver`.
///
/// The redesign changed no behaviour. Live parsing, the 600 ms prompt debounce,
/// tappable chips, autofocus, the launcher mailbox and the DEBUG
/// `-initialInput` hook are all exactly as they were; only their clothes
/// changed.
struct ContentView: View {
    /// Prefilled from `-initialInput` in DEBUG builds, empty otherwise.
    @State private var freeformInput: String = LaunchArguments.initialInput ?? ""
    @State private var displayDriver = ConverterDisplayDriver()
    @FocusState private var inputFieldIsFocused: Bool
    @Environment(\.scenePhase) private var scenePhase

    /// Where the App Shortcut and the Control Center control post their one
    /// request (backlog item 11). Not `@State`: the app owns one mailbox and the
    /// intent writes to it from outside the view's lifetime.
    private let launchRequests = LaunchRequestInbox.shared

    /// The design's canvas is 390pt wide. Letting the poster grow past about
    /// that on an iPad would turn a 140pt numeral into a 300pt one; capping it
    /// keeps the composition and centres it instead.
    private let posterWidth: CGFloat = 430

    var body: some View {
        ScrollView {
            poster
                .padding(.horizontal, 28)
                .padding(.top, 64)
                .padding(.bottom, 40)
                .frame(maxWidth: posterWidth, alignment: .leading)
                .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(PosterPalette.paper.ignoresSafeArea())
        .tint(PosterPalette.accent)
        .onChange(of: freeformInput) {
            displayDriver.inputDidChange(
                to: freeformInput, now: Date(), localZone: TimeZone.current
            )
        }
        .onAppear {
            // Covers the DEBUG prefill without the debounce, so a
            // launch-argument run shows its conversion — or its prompt and
            // chips — immediately.
            showResultWithoutWaiting()
            inputFieldIsFocused = InputFocusPolicy.shouldFocusOnAppear
            // A cold launch from a launcher can perform its intent before the
            // view exists, so the mailbox is drained here as well as below.
            honourPendingLaunchRequest()
        }
        // The warm case: the app was already running, so the intent (or the
        // QA URL) arrives while this view is on screen.
        .onChange(of: launchRequests.pendingRequest) { honourPendingLaunchRequest() }
        .onOpenURL { url in
            guard let request = LaunchURLRouter.request(for: url) else { return }
            launchRequests.post(request)
        }
        // Launch-to-typing is zero taps, and a window returning from the
        // background arrives ready to type — but focus is never taken
        // mid-session. See `InputFocusPolicy`.
        .onChange(of: scenePhase) { previousPhase, currentPhase in
            guard InputFocusPolicy.shouldFocusInput(
                movingFrom: previousPhase, to: currentPhase
            ) else { return }
            inputFieldIsFocused = true
        }
    }

    // MARK: - The poster

    private var poster: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleBlock

            PosterRule()
                .padding(.top, 22)

            Text("Time & places")
                .posterLabel(size: 12)
                .foregroundStyle(PosterPalette.ink)
                .padding(.top, 20)

            inputBox
                .padding(.top, 10)

            PosterArrowSeparator()
                .padding(.top, 26)

            PosterResultSection(displayState: displayDriver.displayState, onChipTap: apply)
                .padding(.top, 22)
        }
    }

    /// `TIME` over `CONVERTER`, set as tight as the design does.
    ///
    /// Two `Text`s with negative stacking rather than one two-line `Text`:
    /// SwiftUI ignores a negative `lineSpacing`, and the design's 0.95
    /// line-height is below what the system font's own line box allows.
    private var titleBlock: some View {
        let titleSize: CGFloat = 76
        return VStack(alignment: .leading, spacing: -titleSize * 0.16) {
            Text("Time")
            Text("Converter")
        }
        .font(PosterTypography.display(size: titleSize))
        .textCase(.uppercase)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .foregroundStyle(PosterPalette.ink)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Time Converter")
    }

    /// The outlined box: the field, then — once there is a conversion — a
    /// hairline and the parsed source echoed back inside the same frame.
    ///
    /// A single-line `TextField` rather than the design's two-row textarea, and
    /// that is a deliberate functional win over a visual one: a vertical-axis
    /// `TextField` turns Return into a newline on iOS and stops calling
    /// `onSubmit`, which is the gesture that bypasses the prompt debounce. The
    /// field scrolls horizontally instead of wrapping; the type size comes down
    /// from the design's 27pt so an ordinary sentence still fits in view.
    private var inputBox: some View {
        PosterBox {
            VStack(alignment: .leading, spacing: 12) {
                TextField(
                    "",
                    text: $freeformInput,
                    prompt: Text("12pm ET in London")
                        .foregroundColor(PosterPalette.quietInk)
                )
                .font(PosterTypography.mono(size: 21))
                .foregroundStyle(PosterPalette.ink)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($inputFieldIsFocused)
                // Submitting is an action, not typing, so it skips the debounce.
                .onSubmit { showResultWithoutWaiting() }
                .accessibilityLabel("Time and places")

                if let sourceEchoLine = displayDriver.displayState.convertedDisplay?.sourceEchoLine {
                    PosterRule(thickness: 1)
                    Text(sourceEchoLine)
                        .font(PosterTypography.mono(size: 12.5, weight: .regular))
                        .foregroundStyle(PosterPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }
        }
    }

    // MARK: - Behaviour (unchanged by the redesign)

    /// `Date()` and `TimeZone.current` live here and nowhere else: the UI is the
    /// injection point that keeps the driver, presenter, parser and conversion
    /// engine pure. Read per call rather than captured, so a device that changes
    /// zone (or crosses midnight) while the app is open is picked up on the next
    /// keystroke.
    private func showResultWithoutWaiting() {
        displayDriver.showWithoutWaiting(
            for: freeformInput, now: Date(), localZone: TimeZone.current
        )
    }

    /// Launcher arrival: empty field, cursor in it, nothing else — or, from the
    /// Mac menu bar, the cursor back in whatever was already there.
    ///
    /// The *decisions* here are tested — what the input becomes
    /// (`LaunchRequest.inputToStartFrom`) and that arriving focuses the field
    /// (`InputFocusPolicy`). What is left is the `@FocusState` write, which only
    /// a running app can prove.
    private func honourPendingLaunchRequest() {
        guard let request = launchRequests.takePendingRequest() else { return }
        if let replacementInput = request.inputToStartFrom {
            freeformInput = replacementInput
            // Driven from the request rather than from `freeformInput`, which
            // was written one line ago: the output area must never lag the
            // field.
            displayDriver.showWithoutWaiting(
                for: replacementInput, now: Date(), localZone: TimeZone.current
            )
        }
        inputFieldIsFocused = InputFocusPolicy.shouldFocusOnLaunchRequest
    }

    /// A chip rewrites the sentence; the sentence stays the single source of
    /// truth and the re-parse follows from it.
    private func apply(_ chip: ReplacementChip) {
        freeformInput = displayDriver.apply(
            chip, to: freeformInput, now: Date(), localZone: TimeZone.current
        )
    }
}

/// The design's own example, in both appearances — the pair to check whenever
/// a colour moves.
#Preview("Poster — light") {
    ContentView()
        .preferredColorScheme(.light)
}

#Preview("Poster — dark") {
    ContentView()
        .preferredColorScheme(.dark)
}
