//
//  IngredientCategorySection.swift
//  claudia-cooks
//

import SwiftUI

struct IngredientCategorySection: View {
    let category: IngredientCategory
    let selectedOptions: Set<String>
    @Binding var otherText: String
    let onToggle: (String) -> Void

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
                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                    ForEach(IngredientCatalog.options(for: category), id: \.self) { option in
                        ingredientChip(for: option)
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

    @ViewBuilder
    private func ingredientChip(for option: String) -> some View {
        let isSelected = selectedOptions.contains(option)

        if isSelected {
            Button {
                onToggle(option)
            } label: {
                Text(option)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .tint(category.accentColor)
            .buttonBorderShape(.roundedRectangle(radius: 10))
        } else {
            Button {
                onToggle(option)
            } label: {
                Text(option)
                    .font(.caption)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.roundedRectangle(radius: 10))
        }
    }
}

#Preview {
    @Previewable @State var otherText = ""

    IngredientCategorySection(
        category: .protein,
        selectedOptions: ["Chicken", "Tofu"],
        otherText: $otherText,
        onToggle: { _ in }
    )
    .padding()
    .frame(width: 260)
}
