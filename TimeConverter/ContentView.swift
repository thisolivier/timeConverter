import SwiftUI

/// The whole app: one input field and one output area.
///
/// Still logic-free: a `switch` over `ConverterDisplayState`, whose three cases
/// arrive fully rendered from `ConverterPresenter`. What the view now owns, and
/// could not delegate, is platform state — keyboard focus and the scene phase —
/// plus the typed string itself. Timing lives in `ConverterDisplayDriver`.
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

    /// Keeps the window feeling like a small utility on Mac Catalyst without
    /// fighting the window's own sizing.
    private let contentWidth: CGFloat = 480

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("TimeConverter")
                .font(.largeTitle.bold())

            TextField("e.g. 12pm ET in London", text: $freeformInput)
                .textFieldStyle(.roundedBorder)
                .font(.title3)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($inputFieldIsFocused)
                // Submitting is an action, not typing, so it skips the debounce.
                .onSubmit { showResultWithoutWaiting() }

            outputArea

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: contentWidth, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: freeformInput) {
            displayDriver.inputDidChange(to: freeformInput, now: Date())
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

    @ViewBuilder
    private var outputArea: some View {
        switch displayDriver.displayState {
        case .hint:
            Text("Type a time to convert")
                .foregroundStyle(.secondary)

        case let .converted(display):
            VStack(alignment: .leading, spacing: 6) {
                Text(display.echoLine)
                    .font(.title3)
                    .textSelection(.enabled)
                Text(display.detailLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        case let .problem(problem):
            VStack(alignment: .leading, spacing: 12) {
                Text(problem.message)
                    .font(.callout)
                    .foregroundStyle(.red)
                if !problem.chips.isEmpty {
                    PromptChipRow(chips: problem.chips, onTap: apply)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// `Date()` lives here and nowhere else: the UI is the injection point that
    /// keeps the driver, presenter, parser and conversion engine pure.
    private func showResultWithoutWaiting() {
        displayDriver.showWithoutWaiting(for: freeformInput, now: Date())
    }

    /// Launcher arrival: empty field, cursor in it, nothing else.
    ///
    /// The *decisions* here are tested — what the input becomes
    /// (`LaunchRequest.inputToStartFrom`) and that arriving focuses the field
    /// (`InputFocusPolicy`). What is left is the `@FocusState` write, which only
    /// a running app can prove.
    private func honourPendingLaunchRequest() {
        guard let request = launchRequests.takePendingRequest() else { return }
        freeformInput = request.inputToStartFrom
        // Driven from the request rather than from `freeformInput`, which was
        // written one line ago: the output area must never lag the field.
        displayDriver.showWithoutWaiting(for: request.inputToStartFrom, now: Date())
        inputFieldIsFocused = InputFocusPolicy.shouldFocusOnLaunchRequest
    }

    /// A chip rewrites the sentence; the sentence stays the single source of
    /// truth and the re-parse follows from it.
    private func apply(_ chip: ReplacementChip) {
        freeformInput = displayDriver.apply(chip, to: freeformInput, now: Date())
    }
}

#Preview {
    ContentView()
}
