import SwiftUI
import TimeConverterCore
import TimeConverterUI

/// DEBUG-only (`-widgetPreview 1`, item 36b): every face of the saved-cities
/// widget — three families by zero to six cities, 12- and 24-hour — drawn at
/// the iPhone's widget sizes, so the simulator can photograph what it cannot
/// place. Sample favourites, the real `WorldClock.readings` at the real
/// time, the real `SavedCitiesWidgetFace`.
///
/// On appearing it also renders every face to a PNG under the app's
/// `Documents/widget-previews/` (`ImageRenderer`, 3×), because `simctl`
/// cannot scroll a screen: the QA script pulls those files out of the
/// container instead of photographing the screen.
struct WidgetPreviewScreen: View {
    static let sampleTypedZones = ["London", "Los Angeles", "Tokyo", "Sao Paulo", "New York", "Lisbon"]
    static let sizes: [(WidgetLayoutPlan.Family, CGSize)] = [
        (.small, CGSize(width: 170, height: 170)),
        (.medium, CGSize(width: 364, height: 170)),
        (.large, CGSize(width: 364, height: 382)),
    ]

    private var sampleFavourites: [FavouriteDestination] {
        Self.sampleTypedZones.compactMap(FavouriteDestination.resolvingTypedZone)
    }

    var body: some View {
        let display = WorldClock.readings(
            favourites: sampleFavourites, offset: 0, now: Date(), localZone: TimeZone.current
        )
        let cities = SavedCitiesWidgetSupport.cities(for: display)
        ScrollView([.vertical, .horizontal]) {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(Self.sizes.enumerated()), id: \.offset) { _, familyAndSize in
                    ForEach(0...WidgetLayoutPlan.maximumCities, id: \.self) { count in
                        ForEach([false, true], id: \.self) { twentyFour in
                            face(
                                family: familyAndSize.0, size: familyAndSize.1,
                                content: SavedCitiesWidgetContent(
                                    cities: Array(cities.prefix(count)), usesTwentyFourHourClock: twentyFour
                                )
                            )
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color(white: 0.35).ignoresSafeArea())
        .task { Self.exportFaces(cities: cities) }
    }

    @MainActor
    private static func exportFaces(cities: [WorldClockRow]) {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        else { return }
        let folder = documents.appendingPathComponent("widget-previews", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for (family, size) in sizes {
            for count in 0...WidgetLayoutPlan.maximumCities {
                for twentyFour in [false, true] {
                    let content = SavedCitiesWidgetContent(
                        cities: Array(cities.prefix(count)), usesTwentyFourHourClock: twentyFour
                    )
                    let renderer = ImageRenderer(
                        content: SavedCitiesWidgetFace(content: content, family: family)
                            .padding(16)
                            .frame(width: size.width, height: size.height)
                            .background(PosterPalette.paper)
                            .environment(\.colorScheme, .light)
                    )
                    renderer.scale = 3
                    let name = "\(family.rawValue)-\(count)-\(twentyFour ? "24h" : "12h").png"
                    try? renderer.uiImage?.pngData()?.write(to: folder.appendingPathComponent(name))
                }
            }
        }
        print("widget previews written to \(folder.path)")
    }

    private func face(family: WidgetLayoutPlan.Family, size: CGSize, content: SavedCitiesWidgetContent) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(family.rawValue) · \(content.cities.count) · \(content.usesTwentyFourHourClock ? "24h" : "12h")")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white)
            SavedCitiesWidgetFace(content: content, family: family)
                .padding(16)
                .frame(width: size.width, height: size.height)
                .background(PosterPalette.paper)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }
}
