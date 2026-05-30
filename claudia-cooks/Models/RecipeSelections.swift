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

    var canGenerate: Bool {
        !isEmpty || !normalizedCustomPrompt.isEmpty
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

        if options.contains(option) {
            options.remove(option)
        } else {
            options.insert(option)
        }

        selectedOptions[category] = options
    }

    mutating func setOtherText(_ text: String, for category: IngredientCategory) {
        otherText[category] = text
    }

    private func normalizedOtherText(for category: IngredientCategory) -> String {
        otherText[category, default: ""]
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
