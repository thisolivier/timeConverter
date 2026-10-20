import SwiftUI

/// Placeholder shell for the converter. The freeform input parser and the
/// disambiguation prompts are specified in backlog item 2 and implemented in
/// items 3–4; until then this view only proves the dev environment works.
struct ContentView: View {
    @State private var freeformInput: String = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("TimeConvertor")
                .font(.largeTitle)
            TextField("e.g. 12pm ET in London", text: $freeformInput)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 400)
            if freeformInput.isEmpty {
                Text("Type a time to convert")
                    .foregroundStyle(.secondary)
            } else {
                Text("Parser not implemented yet — you typed: \(freeformInput)")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
