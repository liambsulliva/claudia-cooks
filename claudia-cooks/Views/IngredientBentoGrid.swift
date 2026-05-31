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
    @Binding var openVariantMenu: (category: IngredientCategory, option: String)?
    let onToggle: (String, IngredientCategory) -> Void
    let onToggleVariant: (String, String, IngredientCategory) -> Void

    var body: some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            ForEach(categories.bentoLayout, id: \.self) { row in
                GridRow {
                    ForEach(row.cells, id: \.self) { cell in
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
                        .gridCellColumns(cell.columnSpan)
                    }
                }
            }
        }
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
