import Foundation
import Observation

/// Owns *when* the output area changes — the one piece of the UI with timing in
/// it, kept out of `ContentView` so it can be unit-tested (backlog item 8).
///
/// ## The rule
///
/// **Results are instant; prompts wait.** A conversion is the answer the user
/// asked for and must never lag a keystroke. A prompt, by contrast, fires
/// constantly on the way to a valid sentence — `1`, `12`, `12p`, `12pm`,
/// `12pm e`… — so showing it immediately means flashing red text on every key.
/// Prompts are therefore held for `promptDelay` (600 ms, decided 2026-10-21),
/// and the output area shows the quiet hint in the meantime rather than a stale
/// conversion that no longer matches the text.
///
/// ## Bypasses
///
/// A chip tap and `onSubmit` skip the wait entirely. The user has *acted*, not
/// typed, and deserves the next prompt at once. Launch (including the DEBUG
/// `-initialInput` prefill) bypasses it too, so a prefilled screenshot run does
/// not photograph an empty hint.
@MainActor
@Observable
public final class ConverterDisplayDriver {
    /// The decided debounce, and the default everywhere but tests.
    public static let defaultPromptDelay: Duration = .milliseconds(600)

    public private(set) var displayState: ConverterDisplayState = .hint

    private let presenter: ConverterPresenter
    private let promptDelay: Duration
    private var pendingPromptTask: Task<Void, Never>?
    /// The input most recently evaluated through a bypass. Guards against the
    /// view's ordinary change notification arriving *after* a chip tap and
    /// re-hiding the prompt the tap just revealed.
    private var inputShownWithoutWaiting: String?

    /// The whole of the package's public construction surface.
    ///
    /// Deliberately parameterless: `ConverterPresenter` and `InputParser` stay
    /// internal to `TimeConverterCore`, so a shell cannot reach past the driver
    /// into the parser, and the public API cannot grow by accident through a
    /// default argument. The injecting initialiser below stays internal for the
    /// package's own tests.
    public convenience init() {
        self.init(presenter: ConverterPresenter())
    }

    init(
        presenter: ConverterPresenter = ConverterPresenter(),
        promptDelay: Duration = ConverterDisplayDriver.defaultPromptDelay
    ) {
        self.presenter = presenter
        self.promptDelay = promptDelay
    }

    // MARK: - Typing

    /// The debounced path: every keystroke.
    public func inputDidChange(to rawInput: String, now: Date, localZone: TimeZone) {
        guard rawInput != inputShownWithoutWaiting else { return }
        inputShownWithoutWaiting = nil
        cancelPendingPrompt()

        let evaluation = presenter.evaluate(rawInput, now: now, localZone: localZone)
        switch evaluation {
        case .hint, .converted:
            displayState = presenter.displayState(for: evaluation)

        case let .prompt(prompt):
            // Quiet until the user pauses. Deliberately not the previous
            // conversion: under freshly edited text that would read as an
            // answer to a question nobody asked.
            displayState = .hint
            pendingPromptTask = Task { [weak self, promptDelay] in
                try? await Task.sleep(for: promptDelay)
                guard !Task.isCancelled, let self else { return }
                self.displayState = .problem(self.presenter.problem(for: prompt))
            }
        }
    }

    // MARK: - Bypasses

    /// Launch, `onSubmit`, and the aftermath of a chip tap: show whatever the
    /// input produces, right now.
    public func showWithoutWaiting(for rawInput: String, now: Date, localZone: TimeZone) {
        cancelPendingPrompt()
        inputShownWithoutWaiting = rawInput
        displayState = presenter.displayState(for: rawInput, now: now, localZone: localZone)
    }

    /// Applies a chip to the sentence and returns the rewritten sentence for
    /// the caller to store. The display updates immediately, so a tap that
    /// uncovers a *second* prompt (`9am CST to IST` → pick Chicago → now IST is
    /// ambiguous) lands on it without a pause.
    public func apply(
        _ chip: ReplacementChip,
        to rawInput: String,
        now: Date,
        localZone: TimeZone
    ) -> String {
        let rewrittenInput = chip.applied(to: rawInput)
        showWithoutWaiting(for: rewrittenInput, now: now, localZone: localZone)
        return rewrittenInput
    }

    // MARK: - Test support

    /// Awaits the in-flight debounce, if any. Lets tests assert the
    /// after-the-pause state without sleeping for a real 600 ms.
    func waitForPendingPrompt() async {
        await pendingPromptTask?.value
    }

    private func cancelPendingPrompt() {
        pendingPromptTask?.cancel()
        pendingPromptTask = nil
    }
}
