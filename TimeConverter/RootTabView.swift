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
/// which is what lands the cursor when the switch happens from Saved. The one
/// exception is the saved-cities widget's tap (`timeconverter://saved`, item
/// 36b): that request is about the Saved tab, so it is consumed here, the
/// Saved tab comes forward, and the field is neither cleared nor focused.
struct RootTabView: View {
    @State private var selectedTab: AppTab = LaunchArguments.opensOnSavedTab ? .saved : .convert
    private let launchRequests = LaunchRequestInbox.shared

    var body: some View {
        if LaunchArguments.showsWidgetPreview {
            WidgetPreviewScreen()
        } else {
            tabs
        }
    }

    private var tabs: some View {
        TabView(selection: $selectedTab) {
            Tab("Convert", systemImage: "arrow.left.arrow.right", value: AppTab.convert) {
                ContentView()
            }
            Tab("Saved", systemImage: "clock", value: AppTab.saved) {
                SavedScreen()
            }
        }
        .tint(PosterPalette.accent)
        .onAppear { honourPendingTabRequest() }
        .onChange(of: launchRequests.pendingRequest) { honourPendingTabRequest() }
        // Here rather than in `ContentView`: a hidden tab is not guaranteed
        // to receive the URL, and the root always is.
        .onOpenURL { url in
            guard let request = LaunchURLRouter.request(for: url) else { return }
            launchRequests.post(request)
        }
    }

    private func honourPendingTabRequest() {
        guard let pendingRequest = launchRequests.pendingRequest else { return }
        if pendingRequest.opensSavedTab {
            _ = launchRequests.takePendingRequest()
            selectedTab = .saved
        } else {
            selectedTab = .convert
        }
    }
}

enum AppTab: Hashable {
    case convert
    case saved
}
