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
    var livePDFData: Data

    var activeSheetID: UUID {
        selectedRecipe?.id ?? sessionID
    }

    init(
        sessionID: UUID,
        framework: RecipeFramework,
        livePDFData: Data = Data()
    ) {
        self.sessionID = sessionID
        self.framework = framework
        self.livePDFData = livePDFData
    }

    func paperSheets(
        selections: RecipeSelections,
        libraryStore: RecipeLibraryStore
    ) -> [PaperSheet] {
        libraryStore.recipes.map { recipe in
            PaperSheet(
                id: recipe.id,
                data: pdfData(for: recipe, libraryStore: libraryStore),
                isBlank: isBlankSheet(recipe, selections: selections, libraryStore: libraryStore),
                framework: recipe.framework
            )
        }
    }

    func pdfData(for recipe: SavedRecipe, libraryStore: RecipeLibraryStore) -> Data? {
        if recipe.id == sessionID {
            return livePDFData.isEmpty ? nil : livePDFData
        }

        return libraryStore.pdfData(for: recipe)
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

    func ensureBlankSession(libraryStore: RecipeLibraryStore) {
        libraryStore.ensureBlankSession(sessionID: sessionID, framework: framework)
    }

    func upsertGeneratedRecipe(
        _ recipe: GeneratedRecipe,
        pdfData: Data,
        libraryStore: RecipeLibraryStore
    ) {
        libraryStore.upsert(
            sessionID: sessionID,
            title: recipe.title,
            framework: framework,
            pdfData: pdfData
        )
    }

    func deleteRecipe(_ recipe: SavedRecipe, libraryStore: RecipeLibraryStore) {
        libraryStore.delete(recipe: recipe)

        if selectedRecipe?.id == recipe.id {
            selectedRecipe = nil
        }

        if recipe.id == sessionID {
            ensureBlankSession(libraryStore: libraryStore)
        }
    }
}
