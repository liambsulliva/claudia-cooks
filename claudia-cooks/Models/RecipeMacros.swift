//
//  RecipeMacros.swift
//  claudia-cooks
//

import Foundation

struct RecipeMacros: Codable, Equatable, Sendable {
    var servings: Int?
    var calories: Int?
    var proteinGrams: Int?
    var carbsGrams: Int?
    var fatGrams: Int?

    enum CodingKeys: String, CodingKey {
        case servings
        case calories
        case proteinGrams = "protein_g"
        case carbsGrams = "carbs_g"
        case fatGrams = "fat_g"
        case protein
        case carbs
        case fat
    }

    init(
        servings: Int? = nil,
        calories: Int? = nil,
        proteinGrams: Int? = nil,
        carbsGrams: Int? = nil,
        fatGrams: Int? = nil
    ) {
        self.servings = servings
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        servings = Self.decodeInt(from: container, forKey: .servings)
        calories = Self.decodeInt(from: container, forKey: .calories)
        proteinGrams = Self.decodeInt(from: container, forKey: .proteinGrams)
            ?? Self.decodeInt(from: container, forKey: .protein)
        carbsGrams = Self.decodeInt(from: container, forKey: .carbsGrams)
            ?? Self.decodeInt(from: container, forKey: .carbs)
        fatGrams = Self.decodeInt(from: container, forKey: .fatGrams)
            ?? Self.decodeInt(from: container, forKey: .fat)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(servings, forKey: .servings)
        try container.encodeIfPresent(calories, forKey: .calories)
        try container.encodeIfPresent(proteinGrams, forKey: .proteinGrams)
        try container.encodeIfPresent(carbsGrams, forKey: .carbsGrams)
        try container.encodeIfPresent(fatGrams, forKey: .fatGrams)
    }

    var hasAnyContent: Bool {
        servings != nil
            || calories != nil
            || proteinGrams != nil
            || carbsGrams != nil
            || fatGrams != nil
    }

    var hasMinimumContent: Bool {
        guard let servings, servings > 0,
              let calories, calories > 0,
              let proteinGrams, proteinGrams >= 0,
              let carbsGrams, carbsGrams >= 0,
              let fatGrams, fatGrams >= 0 else {
            return false
        }

        return true
    }

    var markdownLines: [String] {
        var lines: [String] = []

        if let servings {
            lines.append("Servings: \(servings)")
        }
        if let calories {
            lines.append("Calories: \(calories) kcal")
        }
        if let proteinGrams {
            lines.append("Protein: \(proteinGrams) g")
        }
        if let carbsGrams {
            lines.append("Carbs: \(carbsGrams) g")
        }
        if let fatGrams {
            lines.append("Fat: \(fatGrams) g")
        }

        return lines
    }

    mutating func merge(_ other: RecipeMacros) {
        if let servings = other.servings {
            self.servings = servings
        }
        if let calories = other.calories {
            self.calories = calories
        }
        if let proteinGrams = other.proteinGrams {
            self.proteinGrams = proteinGrams
        }
        if let carbsGrams = other.carbsGrams {
            self.carbsGrams = carbsGrams
        }
        if let fatGrams = other.fatGrams {
            self.fatGrams = fatGrams
        }
    }

    static func parse(markdownLines lines: [String]) -> RecipeMacros? {
        var macros = RecipeMacros()

        for line in lines {
            let normalized = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else {
                continue
            }

            let body = normalized.hasPrefix("- ")
                ? String(normalized.dropFirst(2))
                : normalized

            guard let separator = body.firstIndex(of: ":") else {
                continue
            }

            let label = body[..<separator]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            let valueText = body[body.index(after: separator)...]
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard let value = parseInt(from: valueText) else {
                continue
            }

            switch label {
            case "servings", "serves", "yield":
                macros.servings = value
            case "calories", "calorie", "kcal", "energy":
                macros.calories = value
            case "protein":
                macros.proteinGrams = value
            case "carbs", "carbohydrates", "carb":
                macros.carbsGrams = value
            case "fat", "fats":
                macros.fatGrams = value
            default:
                continue
            }
        }

        return macros.hasMinimumContent ? macros : nil
    }

    static func fromJSONObject(_ object: [String: Any]) -> RecipeMacros? {
        guard let macros = parsingJSONObject(object), macros.hasMinimumContent else {
            return nil
        }

        return macros
    }

    static func parsingJSONObject(_ object: [String: Any]) -> RecipeMacros? {
        var macros = RecipeMacros()
        macros.servings = intValue(from: object["servings"])
        macros.calories = intValue(from: object["calories"])
        macros.proteinGrams = intValue(from: object["protein_g"]) ?? intValue(from: object["protein"])
        macros.carbsGrams = intValue(from: object["carbs_g"]) ?? intValue(from: object["carbs"])
        macros.fatGrams = intValue(from: object["fat_g"]) ?? intValue(from: object["fat"])
        return macros.hasAnyContent ? macros : nil
    }

    private static func parseInt(from text: String) -> Int? {
        let digits = text.filter { $0.isNumber }
        guard !digits.isEmpty, let value = Int(digits) else {
            return nil
        }

        return value
    }

    private static func intValue(from value: Any?) -> Int? {
        switch value {
        case let int as Int:
            return int
        case let number as NSNumber:
            return number.intValue
        case let string as String:
            return parseInt(from: string)
        default:
            return nil
        }
    }

    private static func decodeInt(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> Int? {
        if let value = try? container.decode(Int.self, forKey: key) {
            return value
        }

        if let string = try? container.decode(String.self, forKey: key) {
            return parseInt(from: string)
        }

        return nil
    }
}
