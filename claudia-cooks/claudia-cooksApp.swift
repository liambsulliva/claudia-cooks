//
//  claudia-cooksApp.swift
//  claudia-cooks
//

import SwiftUI

@main
struct ClaudiasCookingApp: App {
    @State private var libraryStore = RecipeLibraryStore()
    @State private var ingredientCatalog = IngredientCatalogStore.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(libraryStore)
                .environment(ingredientCatalog)
        }
        .defaultSize(
            width: AppWindowMetrics.pickerSize.width,
            height: AppWindowMetrics.pickerSize.height
        )
        .windowResizability(.contentMinSize)

        Settings {
            AppSettingsView()
                .environment(ingredientCatalog)
        }
    }
}
