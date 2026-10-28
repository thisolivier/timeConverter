import SwiftUI
import TimeConverterCore
import TimeConverterUI

/// The Convert tab (the whole iOS app until item 31), laid out as the poster in `docs/design/Time
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
///
/// Item 19 added the keyboard choreography: with something typed and the
/// keyboard up, the title and the rule under it collapse away and the result
/// numerals step down, so the input box through the footer all stay above the
/// keyboard. The *decision* is `PosterLayoutMode`, in the core package; what
/// lives here is the observation and the animation.
struct ContentView: View {
    /// Prefilled from `-initialInput` in DEBUG builds, empty otherwise.
    @State private var freeformInput: String = LaunchArguments.initialInput ?? ""
    @State private var displayDriver = ConverterDisplayDriver()
    @State private var keyboardIsVisible: Bool = KeyboardVisibility.initialValue
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

    /// Item 19's decision, taken in the core package and read here.
    private var layoutMode: PosterLayoutMode {
        PosterLayoutMode.mode(forInput: freeformInput, keyboardIsVisible: keyboardIsVisible)
    }

    var body: some View {
        ScrollView {
            poster
                .padding(.horizontal, 28)
                // The design's 64pt of air exists to let the title breathe.
                // With the title collapsed it is 64pt of nothing between the
                // status bar and a text field, so it comes down with it.
                .padding(.top, layoutMode.showsTitleBlock ? 64 : 20)
                .padding(.bottom, 40)
                .frame(maxWidth: posterWidth, alignment: .leading)
                .frame(maxWidth: .infinity)
                // One animation for the whole collapse, out here rather than
                // on the poster itself so the top padding travels with the
                // title instead of jumping under it. Driven by the mode rather
                // than by the keyboard notification, so a change of mind —
                // type, delete, type again — never leaves two animations
                // fighting over the same layout.
                .animation(.easeInOut(duration: 0.24), value: layoutMode)
        }
        .scrollBounceBehavior(.basedOnSize)
        // Drag the content and the keyboard follows your finger — the gesture
        // people already use to get a keyboard out of the way.
        .scrollDismissesKeyboard(.interactively)
        // And the other one: tap anything that isn't interactive. Attached to
        // the scroll view, i.e. the *ancestor*, so it only ever sees taps its
        // children declined — the chips and the text field are buttons and a
        // field, they handle their own taps, and this never fires for them.
        .contentShape(Rectangle())
        .onTapGesture { inputFieldIsFocused = false }
        .background(PosterPalette.paper.ignoresSafeArea())
        .tint(PosterPalette.accent)
        .observingKeyboardVisibility(into: $keyboardIsVisible)
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
        // `timeconverter://convert` is received by `RootTabView` (item 31),
        // which posts it to the same mailbox and brings this tab forward.
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
            if layoutMode.showsTitleBlock {
                // Title and rule in one group, inserted and removed together:
                // the rule's whole job is to close the title block, so a rule
                // left behind would be ruled under nothing.
                VStack(alignment: .leading, spacing: 0) {
                    titleBlock

                    PosterRule()
                        .padding(.top, 22)
                }
                // Fades on the way out while the stack contracts under it,
                // which reads as the poster being pushed up by the keyboard
                // rather than as a view disappearing. Quicker out than in: a
                // collapse should feel like it is making room, and a slow one
                // feels like a glitch.
                .transition(.asymmetric(
                    insertion: .opacity.animation(.easeOut(duration: 0.22).delay(0.04)),
                    removal: .opacity.animation(.easeIn(duration: 0.12))
                ))
            }

            Text("Time & places")
                .posterLabel(size: 12)
                .foregroundStyle(PosterPalette.ink)
                .padding(.top, layoutMode.showsTitleBlock ? 20 : 0)

            inputBox
                .padding(.top, 10)

            PosterArrowSeparator()
                .padding(.top, layoutMode.showsTitleBlock ? 26 : 18)

            PosterResultSection(
                displayState: displayDriver.displayState,
                layoutMode: layoutMode,
                onChipTap: apply
            )
            .padding(.top, layoutMode.showsTitleBlock ? 22 : 16)
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

/// Item 19's collapsed state, without needing a keyboard.
///
/// The preview cannot raise one, and the simulator usually has its software
/// keyboard switched off, so the band this sprint is *about* would otherwise be
/// unviewable anywhere but a device. Same escape hatch as the
/// `-forceCompact 1` launch argument, for the same reason.
#Preview("Poster — compact (keyboard up)") {
    PosterCompactPreview()
}

private struct PosterCompactPreview: View {
    @State private var displayDriver = ConverterDisplayDriver()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Time & places")
                .posterLabel(size: 12)
                .foregroundStyle(PosterPalette.ink)

            PosterBox {
                Text("8pm Lisbon in Sao Paulo")
                    .font(PosterTypography.mono(size: 21))
                    .foregroundStyle(PosterPalette.ink)
            }
            .padding(.top, 10)

            PosterArrowSeparator()
                .padding(.top, 18)

            PosterResultSection(
                displayState: displayDriver.displayState,
                layoutMode: .compact,
                onChipTap: { _ in }
            )
            .padding(.top, 16)
        }
        .padding(.horizontal, 28)
        .padding(.top, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PosterPalette.paper.ignoresSafeArea())
        .onAppear {
            displayDriver.showWithoutWaiting(
                for: "8pm Lisbon in Sao Paulo", now: Date(), localZone: TimeZone.current
            )
        }
    }
}
