//
//  FrameworkDetailView.swift
//  recipe-app
//

import SwiftUI

struct FrameworkDetailView: View {
    let framework: RecipeFramework

    private var otherFrameworks: [RecipeFramework] {
        RecipeFramework.allCases.filter { $0 != framework }
    }

    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 220), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                header

                VStack(alignment: .leading, spacing: 16) {
                    Text("Other Frameworks")
                        .font(.title3)
                        .fontWeight(.semibold)

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(otherFrameworks) { other in
                            NavigationLink(value: other) {
                                FrameworkCardButton(framework: other, compact: true)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(32)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle(framework.title)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 24) {
            Image(systemName: framework.icon)
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(framework.accentColor)
                .frame(width: 88, height: 88)
                .background(framework.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text(framework.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text(framework.tagline)
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Text("Build recipes using the \(framework.title.lowercased()) framework — combine base, protein, toppings, and sauce to create something uniquely yours.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    NavigationStack {
        FrameworkDetailView(framework: .bowl)
    }
}
