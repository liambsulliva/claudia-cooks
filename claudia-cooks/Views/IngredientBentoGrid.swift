//
//  IngredientBentoGrid.swift
//  claudia-cooks
//

import SwiftUI

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

struct IngredientBentoGrid: View {
    let categories: [IngredientCategory]
    let selectedOptions: (IngredientCategory) -> Set<String>
    let otherText: (IngredientCategory) -> Binding<String>
    let onToggle: (String, IngredientCategory) -> Void

    var body: some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            ForEach(categories.bentoLayout, id: \.self) { row in
                GridRow {
                    ForEach(row.cells, id: \.self) { cell in
                        IngredientCategorySection(
                            category: cell.category,
                            selectedOptions: selectedOptions(cell.category),
                            otherText: otherText(cell.category),
                            onToggle: { onToggle($0, cell.category) }
                        )
                        .gridCellColumns(cell.columnSpan)
                    }
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var selections = RecipeSelections()

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
        onToggle: { option, category in
            selections.toggle(option, in: category)
        }
    )
    .padding()
    .frame(width: 560)
}
