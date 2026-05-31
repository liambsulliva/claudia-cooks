//
//  IngredientLineParser.swift
//  claudia-cooks
//

import Foundation

struct ParsedIngredientLine: Equatable, Sendable {
    let amount: String?
    let name: String
}

enum IngredientLineParser {
    private static let unitTokens: Set<String> = [
        "cup", "cups", "c", "tablespoon", "tablespoons", "tbsp", "tbs", "teaspoon", "teaspoons", "tsp",
        "ounce", "ounces", "oz", "pound", "pounds", "lb", "lbs", "gram", "grams", "g",
        "kilogram", "kilograms", "kg", "milliliter", "milliliters", "ml", "liter", "liters", "l",
        "clove", "cloves", "can", "cans", "bunch", "bunches", "head", "heads",
        "slice", "slices", "piece", "pieces", "pinch", "pinches", "dash", "dashes",
        "package", "packages", "stalk", "stalks", "sprig", "sprigs", "fillet", "fillets",
        "stick", "sticks", "bag", "bags", "quart", "quarts", "pint", "pints", "handful", "handfuls"
    ]

    static func parse(_ line: String) -> ParsedIngredientLine {
        let trimmed = stripLeadingArticle(line.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !trimmed.isEmpty else {
            return ParsedIngredientLine(amount: nil, name: trimmed)
        }

        let tokens = trimmed.split(separator: " ").map(String.init)
        guard !tokens.isEmpty, isAmountToken(tokens[0]) else {
            return ParsedIngredientLine(amount: nil, name: trimmed)
        }

        var unitEndIndex = 1
        while unitEndIndex < tokens.count, unitTokens.contains(tokens[unitEndIndex].lowercased()) {
            unitEndIndex += 1
        }

        while unitEndIndex < tokens.count, tokens[unitEndIndex].lowercased() == "of" {
            unitEndIndex += 1
        }

        guard unitEndIndex < tokens.count else {
            return ParsedIngredientLine(amount: nil, name: trimmed)
        }

        let amount = tokens[0..<unitEndIndex].joined(separator: " ")
        let name = tokens[unitEndIndex...].joined(separator: " ")
        guard !name.isEmpty else {
            return ParsedIngredientLine(amount: nil, name: trimmed)
        }

        return ParsedIngredientLine(amount: amount, name: name)
    }

    static func normalizedName(for name: String) -> String {
        name.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func stripLeadingArticle(_ line: String) -> String {
        let lowercased = line.lowercased()
        if lowercased.hasPrefix("an ") {
            return String(line.dropFirst(3))
        }
        if lowercased.hasPrefix("a ") {
            return String(line.dropFirst(2))
        }
        return line
    }

    private static func isAmountToken(_ token: String) -> Bool {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return false
        }

        if trimmed.unicodeScalars.allSatisfy({ CharacterSet.decimalDigits.contains($0) }) {
            return true
        }

        if trimmed.contains("/") {
            let parts = trimmed.split(separator: "/")
            guard parts.count == 2 else {
                return false
            }
            return parts.allSatisfy { part in
                part.unicodeScalars.allSatisfy { CharacterSet.decimalDigits.contains($0) }
            }
        }

        let fractionScalars: [Unicode.Scalar] = ["½", "¼", "¾", "⅓", "⅔", "⅛"].compactMap(\.unicodeScalars.first)
        if trimmed.count == 1, let scalar = trimmed.unicodeScalars.first, fractionScalars.contains(scalar) {
            return true
        }

        if trimmed.range(of: #"^\d+(\.\d+)?$"#, options: .regularExpression) != nil {
            return true
        }

        return false
    }
}
