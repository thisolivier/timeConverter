import SwiftUI
import TimeConverterCore

/// The tap-to-replace chips under a prompt (backlog items 7 and 9).
///
/// Identical on iPhone, iPad and Mac: plain SwiftUI buttons, so a tap and a
/// click are the same gesture and there is no forked model. Every chip arrives
/// fully prepared by the presenter — a label and the edit it performs — so this
/// view decides nothing.
struct PromptChipRow: View {
    let chips: [ReplacementChip]
    let onTap: (ReplacementChip) -> Void

    var body: some View {
        ChipFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(chips) { chip in
                Button(chip.label) { onTap(chip) }
                    .buttonStyle(.bordered)
                    .font(.callout)
            }
        }
    }
}

/// Wraps chips onto as many lines as they need.
///
/// Hand-rolled because the alternatives are worse: an `HStack` clips (Russia
/// offers ten zones), and a horizontal `ScrollView` hides candidates behind a
/// gesture on the one screen where the user is already stuck. This is layout
/// arithmetic only — it reads sizes and assigns positions, and knows nothing
/// about chips, prompts or conversions.
struct ChipFlowLayout: Layout {
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let rows = rows(of: subviews, fittingWidth: proposal.width ?? .infinity)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +)
            + verticalSpacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var verticalOffset = bounds.minY
        for row in rows(of: subviews, fittingWidth: bounds.width) {
            var horizontalOffset = bounds.minX
            for element in row.elements {
                subviews[element.index].place(
                    at: CGPoint(x: horizontalOffset, y: verticalOffset),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(element.size)
                )
                horizontalOffset += element.size.width + horizontalSpacing
            }
            verticalOffset += row.height + verticalSpacing
        }
    }

    // MARK: - Row packing

    private struct Element {
        let index: Int
        let size: CGSize
    }

    private struct Row {
        var elements: [Element] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    /// Greedy first-fit: walk the chips in order, start a new line whenever the
    /// next one would overflow. Order is the presenter's ranking, so it has to
    /// be preserved.
    private func rows(of subviews: Subviews, fittingWidth availableWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var currentRow = Row()

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let widthWithSpacing = currentRow.elements.isEmpty
                ? size.width
                : currentRow.width + horizontalSpacing + size.width

            if !currentRow.elements.isEmpty, widthWithSpacing > availableWidth {
                rows.append(currentRow)
                currentRow = Row()
                currentRow.elements = [Element(index: index, size: size)]
                currentRow.width = size.width
                currentRow.height = size.height
                continue
            }

            currentRow.elements.append(Element(index: index, size: size))
            currentRow.width = widthWithSpacing
            currentRow.height = max(currentRow.height, size.height)
        }

        if !currentRow.elements.isEmpty { rows.append(currentRow) }
        return rows
    }
}
