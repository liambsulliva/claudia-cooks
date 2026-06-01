//
//  RecipeSessionController.swift
//  claudia-cooks
//

import Foundation
import Observation

@MainActor
@Observable
final class RecipeSessionController {
    let sessionID: UUID
    let framework: RecipeFramework

    var selectedRecipe: SavedRecipe?
    var liveRecipeMarkdown: String

    var activeSheetID: UUID {
        selectedRecipe?.id ?? sessionID
    }

    init(
        sessionID: UUID,
        framework: RecipeFramework,
        liveRecipeMarkdown: String = ""
    ) {
        self.sessionID = sessionID
        self.framework = framework
        self.liveRecipeMarkdown = liveRecipeMarkdown
    }

    func paperSheets(
        libraryStore: RecipeLibraryStore,
        sessionMarkdown: String
    ) -> [PaperSheet] {
        libraryStore.recipes.map { recipe in
            let markdown: String?
            if recipe.id == sessionID {
                markdown = sessionMarkdown.isEmpty ? nil : sessionMarkdown
            } else {
                markdown = libraryStore.recipeMarkdown(for: recipe)
            }

            return PaperSheet(
                id: recipe.id,
                markdown: markdown,
                isBlank: isBlankSheet(recipe, libraryStore: libraryStore),
                framework: recipe.framework
            )
        }
    }

    func recipeMarkdown(for recipe: SavedRecipe, libraryStore: RecipeLibraryStore) -> String? {
        if recipe.id == sessionID {
            return liveRecipeMarkdown.isEmpty ? nil : liveRecipeMarkdown
        }

        return libraryStore.recipeMarkdown(for: recipe)
    }

    func isBlankSheet(_ recipe: SavedRecipe, libraryStore: RecipeLibraryStore) -> Bool {
        if recipe.id == sessionID {
            return liveRecipeMarkdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        return recipe.isBlank
    }

    func ensureBlankSession(
        libraryStore: RecipeLibraryStore
    ) {
        ensureBlankSession(
            libraryStore: libraryStore,
            selections: RecipeSelections()
        )
    }

    func ensureBlankSession(
        libraryStore: RecipeLibraryStore,
        selections: RecipeSelections
    ) {
        libraryStore.ensureBlankSession(
            sessionID: sessionID,
            framework: framework,
            selections: selections
        )
    }

    func upsertGeneratedRecipe(
        _ recipe: GeneratedRecipe,
        recipeMarkdown: String,
        selections: RecipeSelections,
        recipeID: UUID? = nil,
        framework activeFramework: RecipeFramework? = nil,
        libraryStore: RecipeLibraryStore
    ) {
        let destinationRecipeID = recipeID ?? sessionID

        libraryStore.upsert(
            sessionID: destinationRecipeID,
            title: recipe.title,
            framework: activeFramework ?? framework,
            recipeMarkdown: recipeMarkdown,
            selections: selections,
            ingredientEntries: GeneratedIngredient.sanitized(recipe.ingredientEntries)
        )
    }

    func deleteRecipe(_ recipe: SavedRecipe, libraryStore: RecipeLibraryStore) {
        libraryStore.delete(recipe: recipe)

        if selectedRecipe?.id == recipe.id {
            selectedRecipe = nil
        }
    }
}
