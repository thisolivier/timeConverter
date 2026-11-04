import SwiftUI
import TimeConverterCore
import TimeConverterUI
import WidgetKit

/// The WidgetKit wrapper around `SavedCitiesWidgetFace`: reads the family
/// from the environment and paints the poster paper as the container
/// background. Everything drawn is in the face, which the app also compiles
/// for its DEBUG preview screen.
struct SavedCitiesWidgetView: View {
    let entry: SavedCitiesEntry
    @Environment(\.widgetFamily) private var widgetFamily

    var body: some View {
        SavedCitiesWidgetFace(content: entry.content, family: Self.family(for: widgetFamily))
            .containerBackground(PosterPalette.paper, for: .widget)
            // A tap opens the Saved tab, not the converter (Olivier, 2026-11-04):
            // the URL is routed by `LaunchURLRouter` and honoured by `RootTabView`.
            .widgetURL(URL(string: "timeconverter://saved"))
    }

    static func family(for widgetFamily: WidgetFamily) -> WidgetLayoutPlan.Family {
        switch widgetFamily {
        case .systemSmall: return .small
        case .systemMedium: return .medium
        default: return .large
        }
    }
}
