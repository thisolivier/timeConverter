import SwiftUI
import TimeConverterCore
import TimeConverterUI

/// The two tabs (item 31): **Convert**, today's poster unchanged, and
/// **Clocks**. The standard system tab bar; the poster palette only colours
/// the selection (rust).
///
/// It also owns one piece of the launcher story: a launcher means "let me type
/// a time", so whenever a request arrives — App Shortcut, Control Center, the
/// QA URL — the Convert tab is brought forward. `ContentView` still drains the
/// mailbox and takes focus exactly as before; it also focuses on appearing,
/// which is what lands the cursor when the switch happens from Clocks.
struct RootTabView: View {
    @State private var selectedTab: AppTab = LaunchArguments.opensOnClocksTab ? .clocks : .convert
    private let launchRequests = LaunchRequestInbox.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Convert", systemImage: "arrow.left.arrow.right", value: AppTab.convert) {
                ContentView()
            }
            Tab("Clocks", systemImage: "clock", value: AppTab.clocks) {
                ClocksScreen()
            }
        }
        .tint(PosterPalette.accent)
        .onAppear { bringConvertForwardIfALaunchIsPending() }
        .onChange(of: launchRequests.pendingRequest) { bringConvertForwardIfALaunchIsPending() }
        // Here rather than in `ContentView`: a hidden tab is not guaranteed
        // to receive the URL, and the root always is.
        .onOpenURL { url in
            guard let request = LaunchURLRouter.request(for: url) else { return }
            launchRequests.post(request)
        }
    }

    private func bringConvertForwardIfALaunchIsPending() {
        guard launchRequests.pendingRequest != nil else { return }
        selectedTab = .convert
    }
}

enum AppTab: Hashable {
    case convert
    case clocks
}
