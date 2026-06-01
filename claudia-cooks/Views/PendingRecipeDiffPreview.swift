//
//  PendingRecipeDiffPreview.swift
//  claudia-cooks
//

import SwiftUI

struct PendingRecipeDiffPreview: View {
    let pendingDiff: RecipeEditPendingDiff
    let framework: RecipeFramework
    var onAcceptChange: (UUID) -> Void
    var onDenyChange: (UUID) -> Void

    private var recipe: GeneratedRecipe {
        pendingDiff.originalRecipe
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(framework.title.uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(1.1)
                    .foregroundStyle(framework.accentColor)

                scalarBlock(
                    section: .title,
                    fallback: recipe.title,
                    fallbackFont: .title2.weight(.bold),
                    fallbackColor: framework.accentColor
                )

                scalarBlock(
                    section: .summary,
                    fallback: recipe.summary,
                    fallbackFont: .body,
                    fallbackColor: .secondary
                )

                recipeSection("Ingredients") {
                    diffList(section: .ingredients, items: recipe.ingredients)
                }

                recipeSection("Steps") {
                    diffList(section: .steps, items: recipe.steps)
                }

                recipeSection("Tips") {
                    diffList(section: .tips, items: recipe.tips)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.separator.opacity(0.55), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    @ViewBuilder
    private func scalarBlock(
        section: RecipeEditSection,
        fallback: String,
        fallbackFont: Font,
        fallbackColor: Color
    ) -> some View {
        let rows = RecipeDiffDisplayBuilder.scalarRows(
            section: section,
            fallback: fallback,
            changes: pendingDiff.changes
        )

        ForEach(groupedRows(rows), id: \.id) { group in
            if let changeID = group.changeID {
                DiffChangeReviewGroup(changeID: changeID, rows: group.rows) { accepted in
                    if accepted {
                        onAcceptChange(changeID)
                    } else {
                        onDenyChange(changeID)
                    }
                }
            } else {
                ForEach(group.rows) { row in
                    diffRow(row, fallbackFont: fallbackFont, fallbackColor: fallbackColor)
                }
            }
        }
    }

    private func recipeSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline.weight(.semibold))
                .padding(.top, 4)

            content()
        }
    }

    private func diffList(section: RecipeEditSection, items: [String]) -> some View {
        let rows = RecipeDiffDisplayBuilder.listRows(
            section: section,
            items: items,
            changes: pendingDiff.changes
        )

        return VStack(alignment: .leading, spacing: 4) {
            if rows.isEmpty {
                Text("No content.")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(groupedRows(rows), id: \.id) { group in
                    if let changeID = group.changeID {
                        DiffChangeReviewGroup(changeID: changeID, rows: group.rows) { accepted in
                            if accepted {
                                onAcceptChange(changeID)
                            } else {
                                onDenyChange(changeID)
                            }
                        }
                    } else {
                        ForEach(group.rows) { row in
                            diffRow(row)
                        }
                    }
                }
            }
        }
    }

    private func diffRow(
        _ row: RecipeDiffDisplayRow,
        fallbackFont: Font = .callout,
        fallbackColor: Color = .primary
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if row.kind == .unchanged {
                Text(row.text)
                    .font(fallbackFont)
                    .foregroundStyle(fallbackColor)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(row.prefix)
                    .font(.callout.monospaced().weight(.semibold))
                    .foregroundStyle(row.prefixColor)
                    .frame(width: 18, alignment: .leading)

                Text(row.text)
                    .font(.callout)
                    .foregroundStyle(row.textColor)
                    .strikethrough(row.kind == .removal, color: row.textColor)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, row.kind == .unchanged ? 0 : 8)
        .padding(.vertical, row.kind == .unchanged ? 0 : 5)
        .background(row.backgroundColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private struct DisplayRowGroup: Identifiable {
        let id: String
        let changeID: UUID?
        var rows: [RecipeDiffDisplayRow]
    }

    private func groupedRows(_ rows: [RecipeDiffDisplayRow]) -> [DisplayRowGroup] {
        var groups: [DisplayRowGroup] = []

        for row in rows {
            if row.kind != .unchanged, let changeID = row.changeID {
                if let lastIndex = groups.indices.last,
                   groups[lastIndex].changeID == changeID {
                    groups[lastIndex].rows.append(row)
                } else {
                    groups.append(
                        DisplayRowGroup(
                            id: changeID.uuidString,
                            changeID: changeID,
                            rows: [row]
                        )
                    )
                }
            } else {
                groups.append(
                    DisplayRowGroup(
                        id: row.id.uuidString,
                        changeID: nil,
                        rows: [row]
                    )
                )
            }
        }

        return groups
    }
}

private struct DiffChangeReviewGroup: View {
    let changeID: UUID
    let rows: [RecipeDiffDisplayRow]
    var onDecision: (Bool) -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                diffRow(row)
                    .overlay(alignment: .bottomTrailing) {
                        if index == rows.count - 1 {
                            reviewControls
                                .offset(y: 18)
                        }
                    }
            }
        }
    }

    private var reviewControls: some View {
        HStack(spacing: 0) {
            reviewButton(title: "Y") {
                onDecision(true)
            }

            Rectangle()
                .fill(reviewBorder)
                .frame(width: 1, height: 10)

            reviewButton(title: "N") {
                onDecision(false)
            }
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(reviewForeground)
        .background(reviewBackground, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(reviewBorder, lineWidth: 1)
        }
    }

    private var reviewBackground: Color {
        colorScheme == .dark ? Color(white: 0.17) : .white
    }

    private var reviewBorder: Color {
        colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.18)
    }

    private var reviewForeground: Color {
        colorScheme == .dark ? Color(white: 0.68) : Color(white: 0.39)
    }

    private func diffRow(_ row: RecipeDiffDisplayRow) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(row.prefix)
                .font(.callout.monospaced().weight(.semibold))
                .foregroundStyle(row.prefixColor)
                .frame(width: 18, alignment: .leading)

            Text(row.text)
                .font(.callout)
                .foregroundStyle(row.textColor)
                .strikethrough(row.kind == .removal, color: row.textColor)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(row.backgroundColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func reviewButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .frame(width: 22, height: 16)
        }
        .buttonStyle(.plain)
    }
}

private extension RecipeDiffDisplayRow {
    var prefix: String {
        switch kind {
        case .unchanged: " "
        case .addition: "+"
        case .removal: "-"
        }
    }

    var prefixColor: Color {
        switch kind {
        case .unchanged: .secondary
        case .addition: .green
        case .removal: .red
        }
    }

    var textColor: Color {
        switch kind {
        case .unchanged: .primary
        case .addition: .green
        case .removal: .red
        }
    }

    var backgroundColor: Color {
        switch kind {
        case .unchanged: .clear
        case .addition: .green.opacity(0.16)
        case .removal: .red.opacity(0.14)
        }
    }
}
