import SwiftUI

/// Wraps a row of chips onto as many lines as they need.
///
/// Hand-rolled because the alternatives are worse: an `HStack` clips (Russia
/// offers ten zones), and a horizontal `ScrollView` hides candidates behind a
/// gesture on the one screen where the user is already stuck.
///
/// This is layout arithmetic only — it reads sizes and assigns positions, and
/// knows nothing about chips, prompts or conversions. That is why it could move
/// here from the iOS app in phase B without carrying any of the poster's
/// styling with it: the Mac's glass prompt wraps its chips by exactly the same
/// rules and in a completely different visual language. The two shells share
/// the packing and disagree about the paint, which is the split this module
/// exists to make.
public struct ChipFlowLayout: Layout {
    private let horizontalSpacing: CGFloat
    private let verticalSpacing: CGFloat

    public init(horizontalSpacing: CGFloat = 8, verticalSpacing: CGFloat = 8) {
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
    }

    public func sizeThatFits(
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

    public func placeSubviews(
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
