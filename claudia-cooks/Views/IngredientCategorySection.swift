//
//  IngredientCategorySection.swift
//  claudia-cooks
//

import SwiftUI

struct IngredientCategorySection: View {
    let category: IngredientCategory
    @Binding var openVariantMenu: (category: IngredientCategory, option: String)?
    let selectionState: (String) -> IngredientOptionSelectionState
    @Binding var otherText: String
    let onToggle: (String) -> Void
    let onToggleVariant: (String, String) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 96), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(category.accentColor)

                Text(category.title)
                    .font(.headline)
                    .foregroundStyle(category.accentColor)
            }

            GlassEffectContainer(spacing: 8) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(IngredientCatalog.optionGroups(for: category), id: \.subgroup) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.subgroup)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(category.accentColor.opacity(0.85))

                            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                                ForEach(group.options, id: \.self) { option in
                                    IngredientOptionChip(
                                        option: option,
                                        category: category,
                                        selectionState: selectionState(option),
                                        isMenuPresented: Binding(
                                            get: {
                                                openVariantMenu?.category == category
                                                    && openVariantMenu?.option == option
                                            },
                                            set: { isPresented in
                                                if isPresented {
                                                    openVariantMenu = (category, option)
                                                } else if openVariantMenu?.category == category,
                                                          openVariantMenu?.option == option {
                                                    openVariantMenu = nil
                                                }
                                            }
                                        ),
                                        onToggle: { onToggle(option) },
                                        onToggleVariant: { variant in
                                            onToggleVariant(option, variant)
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
            }

            TextField("Other \(category.title.lowercased())", text: $otherText)
                .textFieldStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.background.opacity(0.65), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            category.accentColor.opacity(0.22),
                            category.accentColor.opacity(0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(category.accentColor.opacity(0.32), lineWidth: 1)
        }
    }
}

#Preview {
    @Previewable @State var otherText = ""
    @Previewable @State var selections = RecipeSelections()

    @Previewable @State var openVariantMenu: (category: IngredientCategory, option: String)?

    IngredientCategorySection(
        category: .protein,
        openVariantMenu: $openVariantMenu,
        selectionState: { selections.selectionState(for: $0, in: .protein) },
        otherText: $otherText,
        onToggle: { selections.toggle($0, in: .protein) },
        onToggleVariant: { base, variant in
            selections.toggle(base: base, variant: variant, in: .protein)
        }
    )
    .padding()
    .frame(width: 260)
}
