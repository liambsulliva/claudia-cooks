//
//  claudia-cooksApp.swift
//  claudia-cooks
//

import SwiftUI

@main
struct ClaudiasCookingApp: App {
    @State private var libraryStore = RecipeLibraryStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(libraryStore)
        }
        .defaultSize(
            width: AppWindowMetrics.pickerSize.width,
            height: AppWindowMetrics.pickerSize.height
        )
        .windowResizability(.contentMinSize)
    }
}
