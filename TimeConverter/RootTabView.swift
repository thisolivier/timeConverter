import SwiftUI
import TimeConverterCore
import TimeConverterUI

/// The two tabs (item 31): **Convert**, today's poster unchanged, and
/// **Saved** (called Clocks until item 37; the clock icon stays). The
/// standard system tab bar; the poster palette only colours the selection
/// (rust).
///
/// It also owns one piece of the launcher story: a launcher means "let me type
/// a time", so whenever a request arrives — App Shortcut, Control Center, the
/// QA URL — the Convert tab is brought forward. `ContentView` still drains the
/// mailbox and takes focus exactly as before; it also focuses on appearing,
/// which is what lands the cursor when the switch happens from Clocks.
struct RootTabView: View {
    @State private var selectedTab: AppTab = LaunchArguments.opensOnSavedTab ? .saved : .convert
    private let launchRequests = LaunchRequestInbox.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Convert", systemImage: "arrow.left.arrow.right", value: AppTab.convert) {
                ContentView()
            }
            Tab("Saved", systemImage: "clock", value: AppTab.saved) {
                SavedScreen()
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
    case saved
}
