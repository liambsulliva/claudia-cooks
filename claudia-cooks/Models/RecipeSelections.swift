//
//  RecipeSelections.swift
//  claudia-cooks
//

import Foundation

struct RecipeSelections: Equatable {
    var selectedOptions: [IngredientCategory: Set<String>] = [:]
    var otherText: [IngredientCategory: String] = [:]
    var customPrompt: String = ""

    var normalizedCustomPrompt: String {
        customPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// True when MLX has chip selections or a submitted recipe prompt to work from.
    var hasGenerationInput: Bool {
        !ingredientMakeup.isEmpty || !normalizedCustomPrompt.isEmpty
    }

    var canGenerate: Bool {
        hasGenerationInput
    }

    var isEmpty: Bool {
        IngredientCategory.allCases.allSatisfy { category in
            selectedItems(for: category).isEmpty
        }
    }

    func selectedItems(for category: IngredientCategory) -> [String] {
        var items = Array(selectedOptions[category, default: []]).sorted()
        let other = normalizedOtherText(for: category)

        if !other.isEmpty {
            items.append(other)
        }

        return items
    }

    func promptLines(for categories: [IngredientCategory]) -> [String] {
        categories.compactMap { category in
            let items = selectedItems(for: category)

            guard !items.isEmpty else {
                return nil
            }

            return "\(category.promptLabel): \(items.joined(separator: ", "))"
        }
    }

    mutating func toggle(_ option: String, in category: IngredientCategory) {
        var options = selectedOptions[category, default: []]
        let hasBase = options.contains(option)
        let hasVariants = options.contains {
            IngredientSelectionLabel.baseOption(from: $0) == option
                && IngredientSelectionLabel.variantLabel(from: $0) != nil
        }

        if hasBase || hasVariants {
            options = options.filter { IngredientSelectionLabel.baseOption(from: $0) != option }
        } else {
            options.insert(option)
        }

        storeOptions(options, for: category)
    }

    mutating func toggle(base: String, variant: String, in category: IngredientCategory) {
        let key = IngredientSelectionLabel.disambiguated(base: base, variant: variant)
        var options = selectedOptions[category, default: []]

        if options.contains(key) {
            options.remove(key)
        } else {
            options.remove(base)
            options.insert(key)
        }

        storeOptions(options, for: category)
    }

    func selectionState(for base: String, in category: IngredientCategory) -> IngredientOptionSelectionState {
        let options = selectedOptions[category, default: []]
        let variants = options.compactMap { selection -> String? in
            guard IngredientSelectionLabel.baseOption(from: selection) == base else {
                return nil
            }
            return IngredientSelectionLabel.variantLabel(from: selection)
        }
        .sorted()

        return IngredientOptionSelectionState(
            isBaseSelected: options.contains(base),
            variants: variants
        )
    }

    func isOptionActive(_ base: String, in category: IngredientCategory) -> Bool {
        let state = selectionState(for: base, in: category)
        return state.isBaseSelected || !state.variants.isEmpty
    }

    mutating func setOtherText(_ text: String, for category: IngredientCategory) {
        otherText[category] = text
    }

    private mutating func storeOptions(_ options: Set<String>, for category: IngredientCategory) {
        if options.isEmpty {
            selectedOptions.removeValue(forKey: category)
        } else {
            selectedOptions[category] = options
        }
    }

    private func normalizedOtherText(for category: IngredientCategory) -> String {
        otherText[category, default: ""]
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct IngredientOptionSelectionState: Equatable {
    var isBaseSelected: Bool
    var variants: [String]

    func isVariantSelected(_ variant: String) -> Bool {
        variants.contains(variant)
    }
}
