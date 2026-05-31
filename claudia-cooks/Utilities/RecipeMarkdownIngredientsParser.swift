//
//  RecipeMarkdownIngredientsParser.swift
//  claudia-cooks
//

import Foundation

enum RecipeMarkdownIngredientsParser {
    private static let ingredientsSectionTitle = "Ingredients"
    private static let stepsSectionTitle = "Steps"
    private static let placeholderLines: Set<String> = [
        "no ingredients generated yet.",
        "no selections yet."
    ]

    /// True when the line is a numbered step (e.g. `1. Heat the pan`) or appears after `## Steps` in markdown.
    static func isLikelyStepContent(_ text: String, markdown: String? = nil) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return true
        }

        if isNumberedStepLine(trimmed) {
            return true
        }

        if let markdown, originatesBeyondSteps(trimmed, in: markdown) {
            return true
        }

        return false
    }

    /// Bullet lines from the generated recipe's `## Ingredients` section.
    static func ingredients(from markdown: String) -> [String] {
        let stepsStart = stepsSectionStart(in: markdown)
        var results: [String] = []
        var inIngredientsSection = false
        var lineStart = markdown.startIndex

        while lineStart < markdown.endIndex {
            let lineEnd = markdown[lineStart...].firstIndex(of: "\n") ?? markdown.endIndex
            let rawLine = String(markdown[lineStart..<lineEnd])
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

            if !line.isEmpty {
                if let heading = sectionTitle(from: line) {
                    if heading.caseInsensitiveCompare(ingredientsSectionTitle) == .orderedSame {
                        inIngredientsSection = true
                    } else if inIngredientsSection {
                        break
                    } else {
                        inIngredientsSection = false
                    }
                } else if inIngredientsSection {
                    let afterSteps = stepsStart.map { lineStart >= $0 } ?? false

                    if !afterSteps,
                       !isNumberedStepLine(line),
                       let item = bulletListItem(from: line),
                       !isPlaceholder(item) {
                        results.append(item)
                    }
                }
            }

            lineStart = lineEnd < markdown.endIndex ? markdown.index(after: lineEnd) : markdown.endIndex
        }

        return results
    }

    /// Matches a catalog option inside the ingredient name (not the full line with amounts).
    static func catalogCategory(for ingredientName: String) -> IngredientCategory? {
        let normalizedLine = IngredientSelectionLabel.baseOption(from: ingredientName).lowercased()
        var bestMatch: (category: IngredientCategory, length: Int)?

        for category in IngredientCategory.allCases {
            for option in IngredientCatalog.options(for: category) {
                let normalizedOption = option.lowercased()
                guard normalizedLine.contains(normalizedOption) else {
                    continue
                }

                if bestMatch == nil || normalizedOption.count > bestMatch!.length {
                    bestMatch = (category, normalizedOption.count)
                }
            }
        }

        return bestMatch?.category
    }

    private static func sectionTitle(from line: String) -> String? {
        guard line.hasPrefix("## ") else {
            return nil
        }

        let title = String(line.dropFirst(3))
        return stripMarkup(title).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func bulletListItem(from line: String) -> String? {
        guard line.hasPrefix("- ") || line.hasPrefix("* ") else {
            return nil
        }

        return stripMarkup(String(line.dropFirst(2)))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isNumberedStepLine(_ line: String) -> Bool {
        guard let dotRange = line.range(of: ". "),
              !line[..<dotRange.lowerBound].isEmpty,
              line[..<dotRange.lowerBound].allSatisfy(\.isNumber) else {
            return false
        }

        return true
    }

    private static func stepsSectionStart(in markdown: String) -> String.Index? {
        var lineStart = markdown.startIndex

        while lineStart < markdown.endIndex {
            let lineEnd = markdown[lineStart...].firstIndex(of: "\n") ?? markdown.endIndex
            let rawLine = String(markdown[lineStart..<lineEnd])
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

            if let heading = sectionTitle(from: line),
               heading.caseInsensitiveCompare(stepsSectionTitle) == .orderedSame {
                return lineStart
            }

            lineStart = lineEnd < markdown.endIndex ? markdown.index(after: lineEnd) : markdown.endIndex
        }

        return nil
    }

    private static func originatesBeyondSteps(_ text: String, in markdown: String) -> Bool {
        guard let stepsStart = stepsSectionStart(in: markdown) else {
            return false
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return false
        }

        for candidate in [trimmed, "- \(trimmed)", "* \(trimmed)"] {
            if let range = markdown.range(of: candidate), range.lowerBound >= stepsStart {
                return true
            }
        }

        return false
    }

    private static func stripMarkup(_ text: String) -> String {
        var result = text

        if let tagStart = result.firstIndex(of: "<"),
           let tagEnd = result[tagStart...].firstIndex(of: ">") {
            result.removeSubrange(tagStart...tagEnd)
            return stripMarkup(result.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return result
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
    }

    private static func isPlaceholder(_ line: String) -> Bool {
        placeholderLines.contains(line.lowercased())
    }
}
