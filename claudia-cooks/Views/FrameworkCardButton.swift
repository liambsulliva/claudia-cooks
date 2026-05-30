//
//  FrameworkCardButton.swift
//  claudia-cooks
//

import SwiftUI

struct FrameworkCardButton: View {
    let framework: RecipeFramework
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 12) {
            Image(systemName: framework.icon)
                .font(.system(size: compact ? 24 : 36, weight: .semibold))
                .foregroundStyle(framework.accentColor)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: compact ? 0 : 8)

            Text(framework.title)
                .font(compact ? .headline : .title2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            if !compact {
                Text(framework.tagline)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(compact ? 16 : 24)
        .frame(maxWidth: .infinity, minHeight: compact ? 100 : 180, alignment: .topLeading)
        .glassEffect(
            .regular.tint(framework.accentColor.opacity(0.18)).interactive(),
            in: RoundedRectangle(cornerRadius: compact ? 14 : 20, style: .continuous)
        )
        .contentShape(RoundedRectangle(cornerRadius: compact ? 14 : 20, style: .continuous))
    }
}

#Preview {
    FrameworkCardButton(framework: .salad)
        .padding()
        .frame(width: 280)
}
