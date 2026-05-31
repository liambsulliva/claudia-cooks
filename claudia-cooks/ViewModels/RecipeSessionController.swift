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
    var liveClickedBadgeIDs: Set<String> = []

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
        selections: RecipeSelections,
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
                clickedBadgeIDs: clickedBadgeIDs(for: recipe, libraryStore: libraryStore),
                isBlank: isBlankSheet(recipe, selections: selections, libraryStore: libraryStore),
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

    func clickedBadgeIDs(for recipe: SavedRecipe, libraryStore: RecipeLibraryStore) -> Set<String> {
        if recipe.id == sessionID {
            return liveClickedBadgeIDs
        }

        return libraryStore.recipe(for: recipe.id)?.clickedBadgeIDs ?? recipe.clickedBadgeIDs
    }

    func toggleBadge(_ badgeID: String, isClicked: Bool, libraryStore: RecipeLibraryStore) {
        let recipeID = activeSheetID
        var badgeIDs = clickedBadgeIDs(forRecipeID: recipeID, libraryStore: libraryStore)

        if isClicked {
            badgeIDs.insert(badgeID)
        } else {
            badgeIDs.remove(badgeID)
        }

        if recipeID == sessionID {
            liveClickedBadgeIDs = badgeIDs
        }

        libraryStore.setClickedBadgeIDs(badgeIDs, for: recipeID)
    }

    private func clickedBadgeIDs(forRecipeID recipeID: UUID, libraryStore: RecipeLibraryStore) -> Set<String> {
        if recipeID == sessionID {
            return liveClickedBadgeIDs
        }

        return libraryStore.recipe(for: recipeID)?.clickedBadgeIDs ?? []
    }

    func isBlankSheet(
        _ recipe: SavedRecipe,
        selections: RecipeSelections,
        libraryStore: RecipeLibraryStore
    ) -> Bool {
        if recipe.id == sessionID {
            return isBlankPage(selections: selections, libraryStore: libraryStore)
        }

        return recipe.isBlank
    }

    func isBlankPage(
        selections: RecipeSelections,
        libraryStore: RecipeLibraryStore
    ) -> Bool {
        if let selectedRecipe {
            if selectedRecipe.id == sessionID && !selections.isEmpty {
                return false
            }

            return selectedRecipe.isBlank
        }

        guard selections.isEmpty else {
            return false
        }

        return libraryStore.recipe(for: sessionID)?.isBlank ?? true
    }

    func ensureBlankSession(
        libraryStore: RecipeLibraryStore,
        selections: RecipeSelections = RecipeSelections()
    ) {
        libraryStore.ensureBlankSession(
            sessionID: sessionID,
            framework: framework,
            selections: selections
        )
    }

    func loadPersistedBadgeState(libraryStore: RecipeLibraryStore) {
        liveClickedBadgeIDs = libraryStore.recipe(for: sessionID)?.clickedBadgeIDs ?? []
    }

    func upsertGeneratedRecipe(
        _ recipe: GeneratedRecipe,
        recipeMarkdown: String,
        selections: RecipeSelections,
        libraryStore: RecipeLibraryStore
    ) {
        libraryStore.upsert(
            sessionID: sessionID,
            title: recipe.title,
            framework: framework,
            recipeMarkdown: recipeMarkdown,
            selections: selections
        )
        libraryStore.setClickedBadgeIDs(liveClickedBadgeIDs, for: sessionID)
    }

    func deleteRecipe(_ recipe: SavedRecipe, libraryStore: RecipeLibraryStore) {
        libraryStore.delete(recipe: recipe)

        if selectedRecipe?.id == recipe.id {
            selectedRecipe = nil
        }

        if recipe.id == sessionID {
            liveClickedBadgeIDs = []
            ensureBlankSession(libraryStore: libraryStore)
        }
    }
}
