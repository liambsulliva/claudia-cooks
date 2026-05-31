//
//  BlankPageView.swift
//  claudia-cooks
//

import SwiftUI

enum BlankPageStyle {
    case full
    case thumbnail
}

struct FramedBlankPagePreview: View {
    let framework: RecipeFramework

    var body: some View {
        BlankPageView(framework: framework, style: .full)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(.separator.opacity(0.55), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct BlankPageView: View {
    let framework: RecipeFramework
    let style: BlankPageStyle

    var body: some View {
        ZStack {
            Color.white

            switch style {
            case .full:
                VStack(spacing: 16) {
                    Image(systemName: framework.icon)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(framework.accentColor.opacity(0.55))

                    VStack(spacing: 6) {
                        Text("Blank Page")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary.opacity(0.72))

                        Text("Add a prompt or pick ingredients to start building.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 220)
                    }
                }
                .padding(32)

            case .thumbnail:
                VStack(spacing: 4) {
                    Image(systemName: "doc")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary.opacity(0.7))

                    Text("Blank")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary.opacity(0.7))
                }
            }
        }
    }
}
