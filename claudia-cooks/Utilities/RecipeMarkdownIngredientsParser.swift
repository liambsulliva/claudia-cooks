//
//  RecipeMarkdownIngredientsParser.swift
//  claudia-cooks
//

import Foundation

enum RecipeMarkdownIngredientsParser {
    private static let ingredientsSectionTitle = "Ingredients"
    private static let placeholderLines: Set<String> = [
        "no ingredients generated yet.",
        "no selections yet."
    ]

    /// Bullet lines from the generated recipe's `## Ingredients` section.
    static func ingredients(from markdown: String) -> [String] {
        var results: [String] = []
        var inIngredientsSection = false

        for rawLine in markdown.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else {
                continue
            }

            if let heading = sectionTitle(from: line) {
                if heading.caseInsensitiveCompare(ingredientsSectionTitle) == .orderedSame {
                    inIngredientsSection = true
                } else if inIngredientsSection {
                    break
                } else {
                    inIngredientsSection = false
                }
                continue
            }

            guard inIngredientsSection, let item = listItem(from: line) else {
                continue
            }

            guard !isPlaceholder(item) else {
                continue
            }

            results.append(item)
        }

        return results
    }

    /// Matches a catalog option inside the ingredient name (not the full line with amounts).
    static func catalogCategory(for ingredientName: String) -> IngredientCategory? {
        let normalizedLine = ingredientName.lowercased()
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

    private static func listItem(from line: String) -> String? {
        if line.hasPrefix("- ") || line.hasPrefix("* ") {
            return stripMarkup(String(line.dropFirst(2)))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let dotRange = line.range(of: ". "),
           !line[..<dotRange.lowerBound].isEmpty,
           line[..<dotRange.lowerBound].allSatisfy(\.isNumber) {
            return stripMarkup(String(line[dotRange.upperBound...]))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return nil
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
