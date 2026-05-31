//
//  StoredRecipeSelections.swift
//  claudia-cooks
//

import Foundation

struct StoredRecipeSelections: Codable, Equatable, Hashable {
    var selectedOptions: [String: [String]] = [:]
    var otherText: [String: String] = [:]
    var customPrompt: String = ""
}

extension RecipeSelections {
    var ingredientMakeup: IngredientMakeup {
        IngredientMakeup(
            selectedOptions: selectedOptions,
            otherText: otherText.mapValues {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.value.isEmpty }
        )
    }

    init(stored: StoredRecipeSelections) {
        selectedOptions = stored.selectedOptions.reduce(into: [:]) { result, entry in
            guard let category = IngredientCategory(storageKey: entry.key) else {
                return
            }
            result[category, default: []].formUnion(entry.value)
        }
        otherText = stored.otherText.reduce(into: [:]) { result, entry in
            guard let category = IngredientCategory(storageKey: entry.key) else {
                return
            }
            result[category] = entry.value
        }
        customPrompt = stored.customPrompt
    }

    var stored: StoredRecipeSelections {
        StoredRecipeSelections(
            selectedOptions: selectedOptions.reduce(into: [:]) { result, entry in
                result[entry.key.rawValue] = Array(entry.value).sorted()
            },
            otherText: otherText.reduce(into: [:]) { result, entry in
                result[entry.key.rawValue] = entry.value
            },
            customPrompt: customPrompt
        )
    }
}

struct IngredientMakeup: Equatable {
    var selectedOptions: [IngredientCategory: Set<String>]
    var otherText: [IngredientCategory: String]

    var isEmpty: Bool {
        selectedOptions.values.allSatisfy(\.isEmpty) && otherText.isEmpty
    }
}
