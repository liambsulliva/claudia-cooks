//
//  IngredientBentoGrid.swift
//  claudia-cooks
//

import SwiftUI

enum BentoGridMetrics {
    static let gutter: CGFloat = 12
    static let columnCount = 2
}

struct BentoCell: Hashable {
    let category: IngredientCategory
    let columnSpan: Int
}

struct BentoRow: Hashable {
    let cells: [BentoCell]
}

extension Array where Element == IngredientCategory {
    var bentoLayout: [BentoRow] {
        guard let first = first else {
            return []
        }

        var rows = [BentoRow(cells: [BentoCell(category: first, columnSpan: 2)])]
        var remaining = Array(dropFirst())

        while !remaining.isEmpty {
            if remaining.count == 1 {
                rows.append(BentoRow(cells: [BentoCell(category: remaining[0], columnSpan: 2)]))
                break
            }

            let left = remaining.removeFirst()
            let right = remaining.removeFirst()
            rows.append(
                BentoRow(cells: [
                    BentoCell(category: left, columnSpan: 1),
                    BentoCell(category: right, columnSpan: 1)
                ])
            )
        }

        return rows
    }
}

private struct BentoLayoutPlacement {
    let subviewIndex: Int
    let row: Int
    let column: Int
    let columnSpan: Int
}

struct EqualSizeBentoLayoutCache {
    var columnWidths: [CGFloat]
    var rowHeights: [CGFloat]
}

/// Lays out bento cells on a fixed column grid, expanding each cell to the tallest
/// height in its row and the widest width in each column it occupies.
struct EqualSizeBentoLayout: Layout {
    let rows: [BentoRow]
    let gutter: CGFloat

    private var placements: [BentoLayoutPlacement] {
        var result: [BentoLayoutPlacement] = []
        var subviewIndex = 0

        for (rowIndex, row) in rows.enumerated() {
            var column = 0
            for cell in row.cells {
                result.append(
                    BentoLayoutPlacement(
                        subviewIndex: subviewIndex,
                        row: rowIndex,
                        column: column,
                        columnSpan: cell.columnSpan
                    )
                )
                subviewIndex += 1
                column += cell.columnSpan
            }
        }

        return result
    }

    func makeCache(subviews: Subviews) -> EqualSizeBentoLayoutCache {
        computeLayout(subviews: subviews, proposedWidth: nil)
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout EqualSizeBentoLayoutCache
    ) -> CGSize {
        cache = computeLayout(subviews: subviews, proposedWidth: proposal.width)
        let totalWidth = cache.columnWidths.reduce(0, +)
            + gutter * CGFloat(max(0, cache.columnWidths.count - 1))
        let totalHeight = cache.rowHeights.reduce(0, +)
            + gutter * CGFloat(max(0, cache.rowHeights.count - 1))
        return CGSize(width: totalWidth, height: totalHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout EqualSizeBentoLayoutCache
    ) {
        var y = bounds.minY

        for rowIndex in cache.rowHeights.indices {
            let rowHeight = cache.rowHeights[rowIndex]
            let rowPlacements = placements.filter { $0.row == rowIndex }

            for placement in rowPlacements {
                let cellWidth = cellWidth(
                    column: placement.column,
                    columnSpan: placement.columnSpan,
                    columnWidths: cache.columnWidths
                )
                let x = bounds.minX + columnOffset(
                    placement.column,
                    columnWidths: cache.columnWidths
                )

                subviews[placement.subviewIndex].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: cellWidth, height: rowHeight)
                )
            }

            y += rowHeight
            if rowIndex < cache.rowHeights.count - 1 {
                y += gutter
            }
        }
    }

    private func computeLayout(
        subviews: Subviews,
        proposedWidth: CGFloat?
    ) -> EqualSizeBentoLayoutCache {
        var columnWidths = Array(repeating: CGFloat(0), count: BentoGridMetrics.columnCount)

        for placement in placements {
            let natural = subviews[placement.subviewIndex].sizeThatFits(.unspecified)

            if placement.columnSpan == BentoGridMetrics.columnCount {
                distributeFullSpanWidth(
                    needed: natural.width,
                    columnWidths: &columnWidths
                )
            } else {
                let column = placement.column
                columnWidths[column] = max(columnWidths[column], natural.width)
            }
        }

        if let proposedWidth {
            expandColumnsToWidth(proposedWidth, columnWidths: &columnWidths)
        }

        var rowHeights = Array(repeating: CGFloat(0), count: rows.count)

        for placement in placements {
            let cellWidth = cellWidth(
                column: placement.column,
                columnSpan: placement.columnSpan,
                columnWidths: columnWidths
            )
            let measured = subviews[placement.subviewIndex].sizeThatFits(
                ProposedViewSize(width: cellWidth, height: nil)
            )
            rowHeights[placement.row] = max(rowHeights[placement.row], measured.height)
        }

        return EqualSizeBentoLayoutCache(
            columnWidths: columnWidths,
            rowHeights: rowHeights
        )
    }

    private func distributeFullSpanWidth(
        needed: CGFloat,
        columnWidths: inout [CGFloat]
    ) {
        let current = columnWidths.reduce(0, +) + gutter * CGFloat(columnWidths.count - 1)
        guard needed > current else {
            return
        }

        if current <= 0 {
            let perColumn = (needed - gutter) / CGFloat(columnWidths.count)
            for index in columnWidths.indices {
                columnWidths[index] = perColumn
            }
            return
        }

        let scale = needed / current
        for index in columnWidths.indices {
            columnWidths[index] *= scale
        }
    }

    private func expandColumnsToWidth(
        _ proposedWidth: CGFloat,
        columnWidths: inout [CGFloat]
    ) {
        let current = columnWidths.reduce(0, +) + gutter * CGFloat(columnWidths.count - 1)
        let extra = proposedWidth - current
        guard extra > 0 else {
            return
        }

        let share = extra / CGFloat(columnWidths.count)
        for index in columnWidths.indices {
            columnWidths[index] += share
        }
    }

    private func columnOffset(_ column: Int, columnWidths: [CGFloat]) -> CGFloat {
        var offset: CGFloat = 0
        for index in 0..<column {
            offset += columnWidths[index]
            offset += gutter
        }
        return offset
    }

    private func cellWidth(
        column: Int,
        columnSpan: Int,
        columnWidths: [CGFloat]
    ) -> CGFloat {
        var width = CGFloat(0)
        for index in column..<(column + columnSpan) {
            width += columnWidths[index]
            if index < column + columnSpan - 1 {
                width += gutter
            }
        }
        return width
    }
}

struct IngredientBentoGrid: View {
    let categories: [IngredientCategory]
    let selectedOptions: (IngredientCategory) -> Set<String>
    let otherText: (IngredientCategory) -> Binding<String>
    @Binding var openVariantMenu: (category: IngredientCategory, option: String)?
    let onToggle: (String, IngredientCategory) -> Void
    let onToggleVariant: (String, String, IngredientCategory) -> Void

    private var layoutRows: [BentoRow] {
        categories.bentoLayout
    }

    private var layoutCells: [BentoCell] {
        layoutRows.flatMap(\.cells)
    }

    var body: some View {
        EqualSizeBentoLayout(rows: layoutRows, gutter: BentoGridMetrics.gutter) {
            ForEach(layoutCells, id: \.category) { cell in
                categorySection(for: cell)
            }
        }
    }

    private func categorySection(for cell: BentoCell) -> some View {
        IngredientCategorySection(
            category: cell.category,
            openVariantMenu: $openVariantMenu,
            selectionState: { option in
                selectionState(for: option, in: cell.category)
            },
            otherText: otherText(cell.category),
            onToggle: { onToggle($0, cell.category) },
            onToggleVariant: { base, variant in
                onToggleVariant(base, variant, cell.category)
            }
        )
    }

    private func selectionState(
        for option: String,
        in category: IngredientCategory
    ) -> IngredientOptionSelectionState {
        let options = selectedOptions(category)
        let variants = options.compactMap { selection -> String? in
            guard IngredientSelectionLabel.baseOption(from: selection) == option else {
                return nil
            }
            return IngredientSelectionLabel.variantLabel(from: selection)
        }
        .sorted()

        return IngredientOptionSelectionState(
            isBaseSelected: options.contains(option),
            variants: variants
        )
    }
}

#Preview {
    @Previewable @State var selections = RecipeSelections()
    @Previewable @State var openVariantMenu: (category: IngredientCategory, option: String)?

    IngredientBentoGrid(
        categories: RecipeFramework.bowl.applicableCategories,
        selectedOptions: { category in
            selections.selectedOptions[category, default: []]
        },
        otherText: { category in
            Binding(
                get: { selections.otherText[category, default: ""] },
                set: { selections.setOtherText($0, for: category) }
            )
        },
        openVariantMenu: $openVariantMenu,
        onToggle: { option, category in
            selections.toggle(option, in: category)
        },
        onToggleVariant: { base, variant, category in
            selections.toggle(base: base, variant: variant, in: category)
        }
    )
    .padding()
    .frame(width: 560)
}
