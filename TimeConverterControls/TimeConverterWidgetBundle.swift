import SwiftUI
import WidgetKit

/// The extension's entry point since item 36: two widgets out of one
/// extension — the Control Center button (item 11) and the saved-cities
/// home-screen widget. A second extension would mean a second App ID, a
/// second distribution profile and a second export entry for no behaviour;
/// WidgetKit is happy to load any number of widgets from one bundle.
@main
struct TimeConverterWidgetBundle: WidgetBundle {
    var body: some Widget {
        ConvertATimeControl()
        SavedCitiesWidget()
    }
}
