//
//  IngredientCategoryCache.swift
//  claudia-cooks
//

import Foundation

actor IngredientCategoryCache {
    static let shared = IngredientCategoryCache()

    private var memory: [String: IngredientCategory] = [:]

    func category(forNormalizedName normalizedName: String) -> IngredientCategory? {
        memory[normalizedName]
    }

    func store(_ categories: [String: IngredientCategory]) {
        for (name, category) in categories {
            let key = IngredientLineParser.normalizedName(for: name)
            guard !key.isEmpty else {
                continue
            }
            memory[key] = category
        }
    }
}
