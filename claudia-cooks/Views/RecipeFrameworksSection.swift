//
//  RecipeFrameworksSection.swift
//  claudia-cooks
//

import SwiftUI

struct RecipeFrameworksSection: View {
    let onSelect: (RecipeFramework) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 240, maximum: 320), spacing: 20)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            header

            GlassEffectContainer(spacing: 20) {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(RecipeFramework.allCases) { framework in
                        Button {
                            onSelect(framework)
                        } label: {
                            FrameworkCardButton(framework: framework)
                        }
                        .buttonStyle(.plain)
                    }
                }
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
    RecipeFrameworksSection { _ in }
        .padding()
        .frame(width: 800)
}
