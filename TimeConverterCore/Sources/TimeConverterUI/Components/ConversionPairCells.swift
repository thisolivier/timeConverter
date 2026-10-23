import SwiftUI

/// The three pieces one side of the conversion is made of: the caption and the
/// place name, the big time, and the zone line underneath it.
///
/// Extracted from `ConversionPairView` when the stacked axis arrived, because
/// the two axes need the *same cells in a different container*: side by side
/// interleaves them into the rows of a `Grid` (so that the arrow can be
/// centred on the numerals and nothing else), while stacked collects each
/// side's three into a `VStack`. A `VStack` of cells cannot be fed to a `Grid`
/// row, so the shared thing has to be the cells rather than the column — and
/// making that explicit here is what stops the second axis from becoming a
/// second transcription of the design.
///
/// Logic-free and string-free: every value arrives pre-rendered on
/// `ConverterDisplay`, exactly as it does one level up.
///
/// `@MainActor` because it builds views: the modifiers it calls
/// (`posterLabel`, and `View` generally) are main-actor-isolated, and a plain
/// struct's methods are not. Being a `View` would have carried the isolation
/// for free — this is not one, by design, since the whole point is that its
/// pieces are placed into a container rather than being a container.
@MainActor
struct ConversionPairCells {
    let style: ConversionPairStyle
    let scale: ConversionPairScale

    /// `FROM` over `LISBON` on paper; `FROM  LISBON` on one baseline on glass.
    @ViewBuilder
    func header(label: String, placeName: String) -> some View {
        let labelText = Text(label)
            .posterLabel(size: scale.labelSize)
            .foregroundStyle(style.quietInk)

        let placeText = Text(placeName)
            .font(PosterTypography.display(size: scale.placeSize))
            .textCase(.uppercase)
            .foregroundStyle(style.ink)
            .lineLimit(1)
            // A long place name (`Eastern Time (New York, Toronto)` set at
            // 40pt) shrinks rather than truncating: a city name cut mid-word
            // is the one failure mode that makes the result look wrong rather
            // than tight.
            .minimumScaleFactor(0.4)

        if style.stacksLabelAbovePlace {
            VStack(alignment: .leading, spacing: 2) {
                labelText
                placeText
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            // `.firstTextBaseline`, and the design's own 14px gap: on page 3
            // the label is tucked into the place name's baseline rather than
            // floating above it.
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                labelText
                placeText
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// `8:00 PM` — numerals at poster scale with the meridiem small beside
    /// them.
    ///
    /// One `Text`, not two in an `HStack`: composing them into a single run
    /// keeps the numerals and the meridiem on a shared baseline *and* scales
    /// them together, so `12:30 AM` shrinks as one object rather than the two
    /// parts drifting apart. Same trick, same reason, as `PosterResultSection`
    /// on the iPhone — spelled with interpolation rather than that file's `+`,
    /// which is deprecated as of this OS floor.
    func clock(digits: String, meridiem: String) -> some View {
        let digitsRun = Text(digits)
            .font(PosterTypography.display(size: scale.clockSize))
        // The gap is set at the *meridiem's* size, not the numerals', so the
        // space between `4:00` and `PM` stays a thin gap rather than becoming
        // a 124pt hole.
        let gapRun = Text(" ")
            .font(PosterTypography.display(size: scale.meridiemSize))
        let meridiemRun = Text(meridiem)
            .font(PosterTypography.display(size: scale.meridiemSize))

        return Text("\(digitsRun)\(gapRun)\(meridiemRun)")
            .foregroundStyle(style.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.3)
            // The design's `margin-top: 2px` between the place name and the time.
            .padding(.top, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The item-21 zone line, where the design drew `UTC+1`.
    ///
    /// Empty for GMT and UTC, which have no cities by design. Drawn as an
    /// empty `Text` rather than skipped, because in the side-by-side axis the
    /// two columns are rows of one grid: dropping the cell on one side would
    /// shorten the row and pull the other side's line up with it.
    func subLine(_ text: String) -> some View {
        Text(text)
            // 0.10em rather than the design's 0.14em, for the reason the
            // iPhone already tightened the same line: the design was setting
            // `UTC−3`, five characters where generous letterspacing *is* the
            // effect. This slot now holds up to about thirty-five, and at
            // 0.14em it wraps.
            .posterLabel(size: scale.subLineSize, em: 0.10)
            .foregroundStyle(style.quietInk)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
            .fixedSize(horizontal: false, vertical: true)
            // The design's `margin-top: 4px`.
            .padding(.top, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// One side's three cells in a column — the stacked axis's unit.
    @ViewBuilder
    func column(
        label: String,
        placeName: String,
        digits: String,
        meridiem: String,
        subLineText: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            header(label: label, placeName: placeName)
            clock(digits: digits, meridiem: meridiem)
            // Skipped rather than drawn empty here, unlike the grid: a stacked
            // column has no partner row to stay level with, so an empty
            // letterspaced line would just be 14pt of nothing between the
            // numerals and the arrow.
            if !subLineText.isEmpty {
                subLine(subLineText)
            }
        }
    }
}
