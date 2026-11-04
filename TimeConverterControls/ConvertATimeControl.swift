import AppIntents
import SwiftUI
import WidgetKit

/// The Control Center / lock-screen button (backlog item 11, slice 2).
///
/// It is a *launcher and nothing else*: one button, no state, no timeline, no
/// rendered time. Display widgets were dropped as decorative (see
/// `docs/ux-v1-proposal.md`) and nothing in Control Center can accept a typed
/// sentence, so the honest best this can do is put the keyboard in front of the
/// user one tap sooner than the home screen does.
///
/// ## Why this file is so short
///
/// All of the behaviour is `ConvertATimeIntent`, which is compiled into *both*
/// this extension and the app (see `project.yml`). The extension needs the type
/// to resolve the button's action; the app needs it to run `perform()` once it
/// is foregrounded. A control whose intent lives in only one of the two is the
/// usual reason a Control Center button appears to do nothing.
///
/// Listed in `TimeConverterWidgetBundle`, which is the extension's `@main`
/// since the saved-cities widget joined it (item 36). Until then `@main` sat
/// on this type directly — `ControlWidget` supplies its own `main()`.
///
/// `kind` is this control's permanent identity — the string the system stores
/// when the user adds the button to Control Center. Changing it orphans every
/// button already placed, so it never changes.
struct ConvertATimeControl: ControlWidget {
    static let kind = "dev.thisolivier.timeconverter.controls.convert"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: ConvertATimeIntent()) {
                Label("Convert a time", systemImage: "globe.badge.clock")
            }
        }
        .displayName("Convert a time")
        .description("Open Time Converter with an empty field, ready to type.")
    }
}
