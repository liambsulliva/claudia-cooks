//
//  GeneratedRecipe.swift
//  claudia-cooks
//

import Foundation

struct GeneratedRecipe: Codable, Equatable, Sendable {
    var title: String
    var summary: String
    var macros: RecipeMacros?
    var ingredients: [String]
    var ingredientEntries: [GeneratedIngredient]
    var steps: [String]
    var tips: [String]

    init(
        title: String,
        summary: String,
        macros: RecipeMacros? = nil,
        ingredients: [String],
        ingredientEntries: [GeneratedIngredient] = [],
        steps: [String],
        tips: [String]
    ) {
        self.title = title
        self.summary = summary
        self.macros = macros
        self.ingredients = ingredients
        self.ingredientEntries = ingredientEntries
        self.steps = steps
        self.tips = tips
    }

    mutating func syncIngredientsFromEntries() {
        ingredientEntries = GeneratedIngredient.sanitized(ingredientEntries)
        ingredients = ingredientEntries
            .map(\.displayLine)
            .filter { !$0.isEmpty }
    }

    mutating func syncEntriesFromIngredients() {
        ingredientEntries = GeneratedIngredient.sanitized(
            ingredients.map { GeneratedIngredient.fromIngredientLine($0) }
        )
        syncIngredientsFromEntries()
    }

    /// Display lines for markdown; always derived from structured entries when present.
    var markdownIngredientLines: [String] {
        let entries = GeneratedIngredient.sanitized(ingredientEntries)
        guard !entries.isEmpty else {
            return ingredients
        }

        return entries.map(\.displayLine).filter { !$0.isEmpty }
    }

    mutating func applyStructuredIngredientEntries(_ entries: [GeneratedIngredient]) {
        ingredientEntries = GeneratedIngredient.sanitized(entries)
        syncIngredientsFromEntries()
    }
}

extension GeneratedRecipe {
    enum CodingKeys: String, CodingKey {
        case title
        case summary
        case macros
        case ingredients
        case steps
        case tips
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
        macros = try container.decodeIfPresent(RecipeMacros.self, forKey: .macros)
        steps = try container.decodeIfPresent([String].self, forKey: .steps) ?? []
        tips = try container.decodeIfPresent([String].self, forKey: .tips) ?? []

        if let entries = try? container.decode([GeneratedIngredient].self, forKey: .ingredients) {
            ingredientEntries = entries
            ingredients = entries.map(\.displayLine).filter { !$0.isEmpty }
        } else {
            let lines = try container.decodeIfPresent([String].self, forKey: .ingredients) ?? []
            ingredients = lines
            ingredientEntries = lines.map { GeneratedIngredient.fromIngredientLine($0) }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(summary, forKey: .summary)
        try container.encodeIfPresent(macros, forKey: .macros)
        try container.encode(steps, forKey: .steps)
        try container.encode(tips, forKey: .tips)

        if ingredientEntries.isEmpty {
            try container.encode(ingredients, forKey: .ingredients)
        } else {
            try container.encode(ingredientEntries, forKey: .ingredients)
        }
    }
}
