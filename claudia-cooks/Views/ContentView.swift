//
//  ContentView.swift
//  claudia-cooks
//

import SwiftUI

struct ContentView: View {
    @Environment(RecipeLibraryStore.self) private var libraryStore
    @State private var activeFramework: RecipeFramework?
    @State private var initialSelectedRecipeID: UUID?

    private var windowMode: AppWindowMode {
        activeFramework == nil ? .frameworkPicker : .builder
    }

    var body: some View {
        Group {
            if let activeFramework {
                NavigationStack {
                    FrameworkDetailView(
                        framework: activeFramework,
                        initialSelectedRecipeID: initialSelectedRecipeID
                    ) { selectedFramework in
                        initialSelectedRecipeID = nil
                        self.activeFramework = selectedFramework
                    }
                }
                .id(activeFramework)
            } else {
                frameworkPickerRoot
            }
        }
        .windowChrome(mode: windowMode)
        .onAppear(perform: openBuilderIfRecipesExist)
    }

    private func openBuilderIfRecipesExist() {
        guard activeFramework == nil, let mostRecent = libraryStore.recipes.first else {
            return
        }

        activeFramework = mostRecent.framework
        initialSelectedRecipeID = mostRecent.id
    }

    private var frameworkPickerRoot: some View {
        ScrollView {
            RecipeFrameworksSection { framework in
                activeFramework = framework
            }
            .padding(32)
            .frame(maxWidth: AppWindowMetrics.pickerSize.width - 64)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .frame(
            width: AppWindowMetrics.pickerSize.width,
            height: AppWindowMetrics.pickerSize.height
        )
        .fixedSize()
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

#Preview {
    ContentView()
        .environment(RecipeLibraryStore())
        .frame(width: 800, height: 700)
}
