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
/// One view for all three pages. The differences between them are three
/// parameters — `ConversionPairStyle` (paper or glass), `ConversionPairScale`
/// (full or compact) and `ConversionPairAxis` (side by side or stacked) — plus
/// an optional phrase under the arrow, which is page 4's way of keeping the
/// relationship visible when the keyboard has eaten the footer. Nothing else
/// differs, and discovering that is the whole point of extracting this before
/// building either platform.
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
///
/// The stacked axis needs none of that: with one column above the other the
/// arrow is simply the thing between them.
public struct ConversionPairView: View {
    private let display: ConverterDisplay
    private let style: ConversionPairStyle
    private let scale: ConversionPairScale
    private let axis: ConversionPairAxis
    private let arrowLabel: String?

    /// - Parameters:
    ///   - display: the conversion, with every string already rendered by
    ///     `TimeConverterCore`.
    ///   - style: paper (pages 2 and 4) or glass (page 3). Decides the ink, the
    ///     arrow's colour, and whether `FROM` stacks above the place name or
    ///     sits beside it.
    ///   - scale: `.full` for a full-height layout, `.compact` when a keyboard
    ///     is taking the bottom of the screen — or when the pair is stacked
    ///     into a narrow container.
    ///   - axis: `.sideBySide` is the design. `.stacked` is the fallback for
    ///     containers too narrow to draw it, and is chosen by measurement
    ///     rather than by hand — see `GlassPanelMetrics.pairAxis`.
    ///   - arrowLabel: page 4's phrase under the arrow — pass
    ///     `display.offsetPhrase` (`4 hours behind`) to get it, `nil` for the
    ///     plain arrow of pages 2 and 3.
    public init(
        display: ConverterDisplay,
        style: ConversionPairStyle = .paper,
        scale: ConversionPairScale = .full,
        axis: ConversionPairAxis = .sideBySide,
        arrowLabel: String? = nil
    ) {
        self.display = display
        self.style = style
        self.scale = scale
        self.axis = axis
        self.arrowLabel = arrowLabel
    }

    private var cells: ConversionPairCells {
        ConversionPairCells(style: style, scale: scale)
    }

    public var body: some View {
        Group {
            switch axis {
            case .sideBySide: sideBySideBody
            case .stacked: stackedBody
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

    // MARK: - The design's axis

    private var sideBySideBody: some View {
        Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                cells.header(label: "From", placeName: display.sourcePlaceName)
                arrowColumnSpacer
                cells.header(label: "To", placeName: display.targetPlaceName)
            }

            GridRow {
                cells.clock(
                    digits: display.sourceClockDigits, meridiem: display.sourceMeridiem
                )
                arrowCell.gridCellAnchor(.center)
                cells.clock(
                    digits: display.targetClockDigits, meridiem: display.targetMeridiem
                )
            }

            GridRow {
                cells.subLine(display.sourceZoneLine)
                arrowColumnSpacer
                cells.subLine(display.targetZoneLine)
            }
        }
    }

    // MARK: - The narrow fallback

    /// `FROM` above a down arrow above `TO`.
    ///
    /// The arrow is leading-aligned rather than centred, because everything
    /// else in both designs is: a centred arrow over left-ranged numerals reads
    /// as a stray mark rather than as the join between two readings. It is
    /// inset by half the gutter the side-by-side axis would have used, which
    /// puts it under the numerals it is pointing from.
    private var stackedBody: some View {
        VStack(alignment: .leading, spacing: stackedSpacing) {
            cells.column(
                label: "From",
                placeName: display.sourcePlaceName,
                digits: display.sourceClockDigits,
                meridiem: display.sourceMeridiem,
                subLineText: display.sourceZoneLine
            )

            downArrow
                .padding(.leading, scale.arrowColumnWidth / 2)

            cells.column(
                label: "To",
                placeName: display.targetPlaceName,
                digits: display.targetClockDigits,
                meridiem: display.targetMeridiem,
                subLineText: display.targetZoneLine
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Tight enough that the two columns read as one object. The sub-line
    /// above and the caption below already supply their own air.
    private var stackedSpacing: CGFloat { scale.labelSize / 2 }

    /// The iPhone's stroked down arrow, which is the same gesture read
    /// vertically — reused rather than re-transcribed, and tinted by the style
    /// exactly as the horizontal one is.
    private var downArrow: some View {
        PosterArrow()
            .stroke(
                style.arrowTint,
                style: StrokeStyle(
                    lineWidth: scale.arrowSize.height / 8, lineCap: .butt, lineJoin: .miter
                )
            )
            .frame(width: scale.arrowSize.height * 0.62, height: scale.arrowSize.height * 0.76)
            .accessibilityHidden(true)
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
    /// 4:00 PM, Brasilia Standard Time (São Paulo)." Identical on both axes,
    /// because turning the layout does not change what was said.
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

/// The design's own example, drawn the ways the design draws it.
///
/// Built through the real `ConverterDisplayDriver` rather than from a stub
/// display: that is the module's only public route to a `ConverterDisplay`, and
/// it means a preview that renders at all is also proof the parse still works.
/// Spelled `Sao Paulo` without the diacritic because that is what today's
/// parser resolves — see `ConverterPresenterTests`.
private struct ConversionPairPreview: View {
    let style: ConversionPairStyle
    let scale: ConversionPairScale
    var axis: ConversionPairAxis = .sideBySide
    var showsArrowLabel: Bool = false
    var width: CGFloat = 900

    @State private var displayDriver = ConverterDisplayDriver()

    var body: some View {
        Group {
            if let display = displayDriver.displayState.convertedDisplay {
                ConversionPairView(
                    display: display,
                    style: style,
                    scale: scale,
                    axis: axis,
                    arrowLabel: showsArrowLabel ? display.offsetPhrase : nil
                )
            } else {
                Text("no conversion")
            }
        }
        .padding(32)
        .frame(width: width)
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
            .overlay(GlassPalette.offscreenPanelTint)
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

#Preview("Pair — glass, compact, stacked (the Mac dropdown)") {
    ConversionPairPreview(
        style: .glass,
        scale: .compact,
        axis: .stacked,
        width: GlassPanelMetrics.narrow.totalWidth
    )
}

#Preview("Pair — paper, full, dark") {
    ConversionPairPreview(style: .paper, scale: .full)
        .preferredColorScheme(.dark)
}
