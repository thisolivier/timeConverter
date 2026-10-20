import SwiftUI

/// The whole app: one input field and one output area.
///
/// Deliberately minimal for the MVC phase — no pickers, no disambiguation UI.
/// All five prompts render as a single line of text the user reads and retypes
/// against. Parsing runs on every keystroke; it is pure and fast enough that
/// debouncing would only add latency.
struct ContentView: View {
    /// Prefilled from `-initialInput` in DEBUG builds, empty otherwise.
    @State private var freeformInput: String = LaunchArguments.initialInput ?? ""
    @State private var displayState: ConverterDisplayState = .hint

    private let presenter = ConverterPresenter()

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
                .onSubmit(refreshDisplayState)

            outputArea

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: contentWidth, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // `initial: true` covers the DEBUG prefill, so a launch-argument run
        // shows its conversion without waiting for a keystroke.
        .onChange(of: freeformInput, initial: true) {
            refreshDisplayState()
        }
    }

    @ViewBuilder
    private var outputArea: some View {
        switch displayState {
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

        case let .problem(message):
            Text(message)
                .font(.callout)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// `Date()` lives here and nowhere else: the UI is the injection point that
    /// keeps the parser and the conversion engine pure.
    private func refreshDisplayState() {
        displayState = presenter.displayState(for: freeformInput, now: Date())
    }
}

#Preview {
    ContentView()
}
