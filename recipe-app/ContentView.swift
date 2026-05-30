//
//  ContentView.swift
//  recipe-app
//
//  Created by Liam Sullivan on 5/30/26.
//

import SwiftUI

struct ContentView: View {
    private let columns = [
        GridItem(.adaptive(minimum: 240, maximum: 320), spacing: 20)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header

                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(RecipeFramework.allCases) { framework in
                            NavigationLink(value: framework) {
                                FrameworkCardButton(framework: framework)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(32)
                .frame(maxWidth: 900)
                .frame(maxWidth: .infinity)
            }
            .background(Color(nsColor: .windowBackgroundColor))
            .navigationDestination(for: RecipeFramework.self) { framework in
                FrameworkDetailView(framework: framework)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recipe Frameworks")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Pick a framework to start building. Each one gives you a flexible structure for creating your own recipes.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    ContentView()
        .frame(width: 800, height: 700)
}
