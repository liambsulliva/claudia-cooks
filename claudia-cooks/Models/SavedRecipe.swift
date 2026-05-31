//
//  SavedRecipe.swift
//  claudia-cooks
//

import Foundation

struct SavedRecipe: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var framework: RecipeFramework
    var createdAt: Date
    var updatedAt: Date
    var fileName: String
    var isBlank: Bool = false
    var selections: StoredRecipeSelections = StoredRecipeSelections()
}
