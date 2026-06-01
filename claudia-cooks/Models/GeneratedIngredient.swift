//
//  GeneratedIngredient.swift
//  claudia-cooks
//

import Foundation

struct GeneratedIngredient: Codable, Equatable, Hashable, Sendable {
    var quantity: String?
    var name: String
    var variant: String?

    private static let invalidNameTokens: Set<String> = [
        "[object object]",
        "object object",
        "undefined",
        "null"
    ]

    var isValidForPersistence: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return false
        }

        return !Self.invalidNameTokens.contains(trimmedName.lowercased())
    }

    /// Markdown ingredient line: quantity, optional catalog variant, and name in natural reading order.
    var displayLine: String {
        let phrase = naturalNamePhrase
        guard !phrase.isEmpty else {
            return ""
        }

        guard let trimmedQuantity = quantity?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmedQuantity.isEmpty else {
            return phrase
        }

        return "\(trimmedQuantity) \(phrase)"
    }

    init(quantity: String? = nil, name: String, variant: String? = nil) {
        self.quantity = quantity
        self.name = name
        self.variant = variant
    }

    static func fromIngredientLine(_ line: String) -> GeneratedIngredient {
        let parsed = IngredientLineParser.parse(line)
        return GeneratedIngredient(quantity: parsed.amount, name: parsed.name, variant: nil)
    }

    static func sanitized(_ entries: [GeneratedIngredient]) -> [GeneratedIngredient] {
        entries.filter(\.isValidForPersistence)
    }

    private var naturalNamePhrase: String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return ""
        }

        guard let trimmedVariant = variant?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmedVariant.isEmpty else {
            return trimmedName
        }

        let variantLower = trimmedVariant.lowercased()

        if let catalogBase = Self.matchingCatalogBase(in: trimmedName) {
            let baseLower = catalogBase.lowercased()

            if Self.prefersVariantBeforeBase(variantLower) {
                return Self.prefixedVariantPhrase(variant: variantLower, base: baseLower, name: trimmedName)
            }

            if let matchingToken = Self.matchingVariantToken(in: trimmedName, variant: variantLower) {
                return "\(baseLower) \(matchingToken.lowercased())"
            }

            return "\(baseLower) \(Self.naturalVariantSuffix(variantLower))"
        }

        if let matchingToken = Self.matchingVariantToken(in: trimmedName, variant: variantLower) {
            return Self.nameKeepingVariantContext(trimmedName, variant: variantLower, matchingToken: matchingToken)
        }

        return "\(variantLower) \(trimmedName)"
    }

    private static func matchingCatalogBase(in name: String) -> String? {
        let normalizedName = name.lowercased()
        var bestMatch: (option: String, length: Int)?

        for category in IngredientCategory.allCases {
            for option in IngredientCatalog.options(for: category) {
                let normalizedOption = option.lowercased()
                guard normalizedName.contains(normalizedOption) else {
                    continue
                }

                if bestMatch == nil || normalizedOption.count > bestMatch!.length {
                    bestMatch = (option, normalizedOption.count)
                }
            }
        }

        return bestMatch?.option
    }

    private static func prefersVariantBeforeBase(_ variantLower: String) -> Bool {
        if variantLower.contains(" ") {
            return true
        }

        return prefixVariants.contains(variantLower)
    }

    private static func prefixedVariantPhrase(variant: String, base: String, name: String) -> String {
        let normalizedName = name.lowercased()
        let candidate = "\(variant) \(base)"
        if normalizedName.contains(candidate) {
            return candidate
        }

        if normalizedName.hasPrefix(variant),
           normalizedName.dropFirst(variant.count).trimmingCharacters(in: .whitespaces).hasPrefix(base) {
            return candidate
        }

        return candidate
    }

    private static func matchingVariantToken(in name: String, variant: String) -> String? {
        name
            .split(separator: " ")
            .map(String.init)
            .first { tokensShareStem($0.lowercased(), variant) }
    }

    private static func nameKeepingVariantContext(
        _ name: String,
        variant: String,
        matchingToken: String
    ) -> String {
        let tokens = name.split(separator: " ").map(String.init)
        guard let matchIndex = tokens.firstIndex(where: { tokensShareStem($0.lowercased(), variant) }) else {
            return name
        }

        if let catalogBase = matchingCatalogBase(in: name) {
            return "\(catalogBase.lowercased()) \(matchingToken.lowercased())"
        }

        var kept: [String] = []
        if matchIndex > 0 {
            kept.append(tokens[matchIndex - 1])
        }
        kept.append(matchingToken)
        return kept.joined(separator: " ").lowercased()
    }

    private static func naturalVariantSuffix(_ variantLower: String) -> String {
        if variantLower.hasSuffix("s") {
            return variantLower
        }

        return "\(variantLower)s"
    }

    private static func tokensShareStem(_ lhs: String, _ rhs: String) -> Bool {
        if lhs == rhs {
            return true
        }

        if lhs.hasPrefix(rhs) || rhs.hasPrefix(lhs) {
            return true
        }

        if lhs.hasSuffix("s"), lhs.dropLast() == rhs {
            return true
        }

        if rhs.hasSuffix("s"), rhs.dropLast() == lhs {
            return true
        }

        return false
    }

    private static let prefixVariants: Set<String> = [
        "aged", "black", "brown", "canned", "clarified", "cooking", "cremini", "dry", "dried",
        "extra", "firm", "fresh", "frozen", "full-bodied", "green", "ground", "large",
        "light", "low-moisture", "mild", "orange", "peeled", "purple", "red", "regular",
        "roasted", "salted", "sharp", "shell-on", "shredded", "smoked", "soft", "silken",
        "sweet", "tri-color", "unsalted", "white", "whole", "wild"
    ]
}
