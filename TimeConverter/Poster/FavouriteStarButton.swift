import SwiftUI
import TimeConverterCore
import TimeConverterUI

/// The star beside the target header (item 31): `IN LONDON ☆` / `★`.
///
/// Tapping adds the destination to the Clocks tab, or removes it. Reads the
/// store from the environment *optionally*, so a preview or any host without
/// one simply draws no star rather than crashing.
struct FavouriteStarButton: View {
    let destination: FavouriteDestination
    @Environment(FavouritesStore.self) private var favouritesStore: FavouritesStore?

    var body: some View {
        if let favouritesStore {
            let isFavourite = favouritesStore.isFavourite(destination)
            Button {
                favouritesStore.toggle(destination)
            } label: {
                Image(systemName: isFavourite ? "star.fill" : "star")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(PosterPalette.ink)
                    // A 44pt hit area without moving the header's layout.
                    .padding(12)
                    .contentShape(Rectangle())
                    .padding(-12)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isFavourite ? "Remove from Clocks" : "Add to Clocks")
        }
    }
}
