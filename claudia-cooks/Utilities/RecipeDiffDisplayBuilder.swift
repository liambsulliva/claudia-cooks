//
//  RecipeDiffDisplayBuilder.swift
//  claudia-cooks
//

import Foundation

struct RecipeDiffDisplayRow: Identifiable, Equatable {
    enum Kind: Equatable {
        case unchanged
        case addition
        case removal
    }

    let id = UUID()
    var kind: Kind
    var text: String
    var changeID: UUID?

    static func unchanged(text: String) -> RecipeDiffDisplayRow {
        RecipeDiffDisplayRow(kind: .unchanged, text: text)
    }

    static func addition(text: String, changeID: UUID? = nil) -> RecipeDiffDisplayRow {
        RecipeDiffDisplayRow(kind: .addition, text: text, changeID: changeID)
    }

    static func removal(text: String, changeID: UUID? = nil) -> RecipeDiffDisplayRow {
        RecipeDiffDisplayRow(kind: .removal, text: text, changeID: changeID)
    }
}

enum RecipeDiffDisplayBuilder {
    static func scalarRows(
        section: RecipeEditSection,
        fallback: String,
        changes allChanges: [RecipeEditAppliedChange]
    ) -> [RecipeDiffDisplayRow] {
        let sectionChanges = sectionChanges(for: section, in: allChanges)
        if sectionChanges.isEmpty {
            return [.unchanged(text: fallback)]
        }
        return diffRows(for: sectionChanges)
    }

    static func listRows(
        section: RecipeEditSection,
        items: [String],
        changes allChanges: [RecipeEditAppliedChange]
    ) -> [RecipeDiffDisplayRow] {
        var rows: [RecipeDiffDisplayRow] = []
        var remainingChanges = sectionChanges(for: section, in: allChanges)

        for (index, item) in items.enumerated() {
            appendAdditions(at: index, from: &remainingChanges, to: &rows)

            if let changeIndex = remainingChanges.firstIndex(where: { matches($0, item: item, index: index) }) {
                let change = remainingChanges.remove(at: changeIndex)
                rows.append(contentsOf: diffRows(for: [change]))
            } else {
                rows.append(.unchanged(text: item))
            }
        }

        appendAdditions(at: items.count, from: &remainingChanges, to: &rows)

        for change in remainingChanges {
            rows.append(contentsOf: diffRows(for: [change]))
        }

        return rows
    }

    private static func appendAdditions(
        at index: Int,
        from changes: inout [RecipeEditAppliedChange],
        to rows: inout [RecipeDiffDisplayRow]
    ) {
        let additions = changes
            .enumerated()
            .filter { _, change in
                change.before == nil && change.after != nil && (change.index ?? Int.max) == index
            }
            .map(\.offset)
            .reversed()

        for additionIndex in additions {
            let change = changes.remove(at: additionIndex)
            rows.append(contentsOf: diffRows(for: [change]))
        }
    }

    private static func diffRows(for changes: [RecipeEditAppliedChange]) -> [RecipeDiffDisplayRow] {
        changes.flatMap { change -> [RecipeDiffDisplayRow] in
            switch (change.before, change.after) {
            case (.some(let before), .some(let after)):
                return [
                    .removal(text: before, changeID: change.id),
                    .addition(text: after, changeID: change.id)
                ]
            case (.some(let before), .none):
                return [.removal(text: before, changeID: change.id)]
            case (.none, .some(let after)):
                return [.addition(text: after, changeID: change.id)]
            case (.none, .none):
                return []
            }
        }
    }

    private static func sectionChanges(
        for section: RecipeEditSection,
        in changes: [RecipeEditAppliedChange]
    ) -> [RecipeEditAppliedChange] {
        changes.filter { $0.section == section }
    }

    private static func matches(_ change: RecipeEditAppliedChange, item: String, index: Int) -> Bool {
        if let before = change.before,
           normalized(before) == normalized(item) {
            return true
        }

        return change.index == index && change.before != nil
    }

    private static func normalized(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .lowercased()
    }
}
