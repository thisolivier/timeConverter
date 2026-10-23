import SwiftUI
import TimeConverterCore

/// The side-by-side conversion, as drawn on pages 2, 3 and 4 of
/// `docs/design/Time Converter-selection.pdf`:
///
/// ```
///   FROM                           TO
///   LISBON              ──▶        SÃO PAULO
///   8:00 PM                        4:00 PM
///   Western European Time          Brasilia Standard Time
/// ```
///
/// One view for all three pages. The differences between them are two
/// parameters — `ConversionPairStyle` (paper or glass) and
/// `ConversionPairScale` (full or compact) — plus an optional phrase under the
/// arrow, which is page 4's way of keeping the relationship visible when the
/// keyboard has eaten the footer. Nothing else differs, and discovering that is
/// the whole point of extracting this before building either platform.
///
/// Logic-free, like every other view in this app: every string arrives
/// pre-rendered on `ConverterDisplay`, including — new in phase A — the source
/// side's clock split and zone line, which the iPhone's single-column layout
/// never needed.
///
/// ## No UTC offsets
///
/// The designs draw `UTC+1` and `UTC−3` under the two times. This draws the
/// item-21 zone lines instead (`Western European Time (Lisbon)`), on every
/// platform, because item 21 is the newer decision and deliberately took the
/// offsets off the iPhone for being the one thing on screen nobody reads. That
/// is working assumption 1 of the sprint plan; if Olivier rules the other way,
/// this view changes in one place and the core gives back
/// `ZoneReading.utcOffsetDescription`, which never went anywhere.
///
/// ## Why a `Grid`
///
/// The arrow has to sit on the **vertical centre of the numerals**, not of the
/// column — the columns are taller than the numerals by a label and a sub-line,
/// and centring on the column puts the arrow through the bottom of the digits.
/// A `Grid` makes that structural: the numerals are a row, the arrow is the
/// middle cell of that row, and `gridCellAnchor(.center)` is the entire
/// alignment logic. The alternative — a custom `VerticalAlignment` — does not
/// work here, because a guide set inside a `VStack` does not propagate to the
/// stack's own vertical guide, so it would have to be computed from hard-coded
/// line heights and would drift the first time a font metric changed.
public struct ConversionPairView: View {
    private let display: ConverterDisplay
    private let style: ConversionPairStyle
    private let scale: ConversionPairScale
    private let arrowLabel: String?

    /// - Parameters:
    ///   - display: the conversion, with every string already rendered by
    ///     `TimeConverterCore`.
    ///   - style: paper (pages 2 and 4) or glass (page 3). Decides the ink, the
    ///     arrow's colour, and whether `FROM` stacks above the place name or
    ///     sits beside it.
    ///   - scale: `.full` for a full-height layout, `.compact` when a keyboard
    ///     is taking the bottom of the screen.
    ///   - arrowLabel: page 4's phrase under the arrow — pass
    ///     `display.offsetPhrase` (`4 hours behind`) to get it, `nil` for the
    ///     plain arrow of pages 2 and 3.
    public init(
        display: ConverterDisplay,
        style: ConversionPairStyle = .paper,
        scale: ConversionPairScale = .full,
        arrowLabel: String? = nil
    ) {
        self.display = display
        self.style = style
        self.scale = scale
        self.arrowLabel = arrowLabel
    }

    public var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                header(label: "From", placeName: display.sourcePlaceName)
                arrowColumnSpacer
                header(label: "To", placeName: display.targetPlaceName)
            }

            GridRow {
                clock(digits: display.sourceClockDigits, meridiem: display.sourceMeridiem)
                arrowCell.gridCellAnchor(.center)
                clock(digits: display.targetClockDigits, meridiem: display.targetMeridiem)
            }

            GridRow {
                subLine(display.sourceZoneLine)
                arrowColumnSpacer
                subLine(display.targetZoneLine)
            }
        }
        // One element per *column* would be ideal, but a `Grid` interleaves the
        // two columns row by row, so VoiceOver's reading order without this is
        // "From, To, 8:00 PM, 4:00 PM, …". Combining the whole pair into one
        // label puts the two readings back in the order a person would say
        // them. The arrow is decorative in the plain case and already carries
        // its own label in the labeled case, so it is excluded either way.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Cells

    /// `FROM` over `LISBON` on paper; `FROM  LISBON` on one baseline on glass.
    @ViewBuilder
    private func header(label: String, placeName: String) -> some View {
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
    private func clock(digits: String, meridiem: String) -> some View {
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
    /// empty `Text` rather than skipped, because the two columns are rows of
    /// one grid: dropping the cell on one side would shorten the row and pull
    /// the other side's line up with it.
    private func subLine(_ text: String) -> some View {
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

    // MARK: - The middle column

    @ViewBuilder
    private var arrowCell: some View {
        if let arrowLabel {
            PosterLabeledArrow(
                label: arrowLabel,
                tint: style.arrowTint,
                arrowSize: scale.labeledArrowSize,
                labelSize: scale.arrowLabelSize
            )
            .frame(width: middleColumnWidth)
        } else {
            PosterRightArrow()
                .fill(style.arrowTint)
                .frame(width: scale.arrowSize.width, height: scale.arrowSize.height)
                .frame(width: middleColumnWidth)
                .accessibilityHidden(true)
        }
    }

    /// The design's fixed gutter — wider when the arrow is carrying a phrase,
    /// because a label that overruns its column lands on the numerals in the
    /// next one.
    private var middleColumnWidth: CGFloat {
        arrowLabel == nil ? scale.arrowColumnWidth : scale.labeledArrowColumnWidth
    }

    /// Holds the middle column open in the rows the arrow is not in, so the
    /// grid's column width is the design's fixed gutter rather than whatever
    /// the arrow happened to measure.
    private var arrowColumnSpacer: some View {
        Color.clear.frame(width: middleColumnWidth, height: 0)
    }

    // MARK: - Spoken form

    /// Read as two readings of one instant, in the order the screen puts them:
    /// "From Lisbon, 8:00 PM, Western European Time (Lisbon). To São Paulo,
    /// 4:00 PM, Brasilia Standard Time (São Paulo)."
    private var accessibilityDescription: String {
        let source = spokenColumn(
            label: "From",
            placeName: display.sourcePlaceName,
            digits: display.sourceClockDigits,
            meridiem: display.sourceMeridiem,
            subLine: display.sourceZoneLine
        )
        let target = spokenColumn(
            label: "To",
            placeName: display.targetPlaceName,
            digits: display.targetClockDigits,
            meridiem: display.targetMeridiem,
            subLine: display.targetZoneLine
        )
        return "\(source) \(target)"
    }

    private func spokenColumn(
        label: String,
        placeName: String,
        digits: String,
        meridiem: String,
        subLine: String
    ) -> String {
        [label, placeName, "\(digits) \(meridiem)", subLine]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
            + "."
    }
}

// MARK: - Previews

/// The design's own example, drawn the three ways the design draws it.
///
/// Built through the real `ConverterDisplayDriver` rather than from a stub
/// display: that is the module's only public route to a `ConverterDisplay`, and
/// it means a preview that renders at all is also proof the parse still works.
/// Spelled `Sao Paulo` without the diacritic because that is what today's
/// parser resolves — see `ConverterPresenterTests`.
private struct ConversionPairPreview: View {
    let style: ConversionPairStyle
    let scale: ConversionPairScale
    var showsArrowLabel: Bool = false

    @State private var displayDriver = ConverterDisplayDriver()

    var body: some View {
        Group {
            if let display = displayDriver.displayState.convertedDisplay {
                ConversionPairView(
                    display: display,
                    style: style,
                    scale: scale,
                    arrowLabel: showsArrowLabel ? display.offsetPhrase : nil
                )
            } else {
                Text("no conversion")
            }
        }
        .padding(32)
        .frame(width: 900)
        .background(previewBackground)
        .onAppear {
            displayDriver.showWithoutWaiting(
                for: "8pm Lisbon in Sao Paulo", now: Date(), localZone: TimeZone.current
            )
        }
    }

    @ViewBuilder
    private var previewBackground: some View {
        switch style {
        case .paper:
            PosterPalette.paper
        case .glass:
            // Stands in for the desktop a real panel floats over — a material
            // previewed against a flat colour looks like a flat colour.
            LinearGradient(
                colors: [Color(red: 0.31, green: 0.43, blue: 0.62), Color(red: 0.13, green: 0.22, blue: 0.37)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(GlassPalette.panelTint)
            .background(GlassPalette.panelMaterial)
        }
    }
}

#Preview("Pair — paper, full (page 2)") {
    ConversionPairPreview(style: .paper, scale: .full)
}

#Preview("Pair — glass, full (page 3)") {
    ConversionPairPreview(style: .glass, scale: .full)
}

#Preview("Pair — paper, compact + labeled arrow (page 4)") {
    ConversionPairPreview(style: .paper, scale: .compact, showsArrowLabel: true)
}

#Preview("Pair — paper, full, dark") {
    ConversionPairPreview(style: .paper, scale: .full)
        .preferredColorScheme(.dark)
}
