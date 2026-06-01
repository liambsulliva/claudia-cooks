//
//  RecipeEditPendingDiff.swift
//  claudia-cooks
//

import Foundation

struct RecipeEditPendingDiff: Equatable, Sendable {
    var originalRecipe: GeneratedRecipe
    var proposedRecipe: GeneratedRecipe
    var changes: [RecipeEditAppliedChange]

    var hasChanges: Bool {
        !changes.isEmpty
    }
}
