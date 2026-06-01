//
//  RecipeFramework.swift
//  claudia-cooks
//

import Foundation

enum RecipeFramework: String, CaseIterable, Codable, Identifiable, Sendable {
    case handhelds
    case bowls
    case soups
    case sautes
    case braises
    case bakes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .handhelds: "Handhelds"
        case .bowls: "Bowls"
        case .soups: "Soups"
        case .sautes: "Sautés"
        case .braises: "Braises"
        case .bakes: "Bakes"
        }
    }

    var tagline: String {
        switch self {
        case .handhelds: "Stacked, portable, satisfying"
        case .bowls: "Balanced layers in one vessel"
        case .soups: "Comfort in every spoonful"
        case .sautes: "Fast heat, vivid flavor"
        case .braises: "Low and slow until tender"
        case .bakes: "Oven heat, golden finishes"
        }
    }

    /// Representative dish styles shown on framework cards.
    var dishExamples: String {
        switch self {
        case .handhelds: "Sandwiches, tacos, wraps, burgers"
        case .bowls: "Salads, grain bowls, poke, pasta"
        case .soups: "Chowders, broths, stews, bisques"
        case .sautes: "Stir-fries, pan-sears, scrambles, omelets"
        case .braises: "Pot roasts, short ribs, slow-cooked meats"
        case .bakes: "Casseroles, roasts, pastries, gratins"
        }
    }

    var icon: String {
        switch self {
        case .handhelds: "square.stack.3d.up.fill"
        case .bowls: "circle.grid.2x2.fill"
        case .soups: "mug.fill"
        case .sautes: "flame.fill"
        case .braises: "hourglass.bottomhalf.filled"
        case .bakes: "oven.fill"
        }
    }

    /// Prior framework titles stored in older recipe markdown bodies.
    var legacyTitles: [String] {
        switch self {
        case .handhelds: ["Sandwich"]
        case .bowls: ["Salad", "Bowl"]
        case .soups: ["Soup"]
        case .sautes: ["Stir-Fry"]
        case .braises: ["Braise"]
        case .bakes: []
        }
    }

    var applicableCategories: [IngredientCategory] {
        switch self {
        case .handhelds:
            [.protein, .carbs, .produce, .dairy, .fats, .aromatics, .spices, .acids, .enhancers]
        case .bowls:
            IngredientCategory.allCases
        case .soups, .braises:
            [.protein, .carbs, .produce, .dairy, .fats, .aromatics, .spices, .acids, .liquids, .enhancers]
        case .sautes:
            [.protein, .carbs, .produce, .fats, .aromatics, .spices, .acids, .liquids, .enhancers]
        case .bakes:
            [.protein, .carbs, .produce, .dairy, .fats, .aromatics, .spices, .liquids, .enhancers]
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        if let match = RecipeFramework(rawValue: value) {
            self = match
            return
        }
        guard let migrated = RecipeFramework.migratingLegacyRawValue(value) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown recipe framework: \(value)"
            )
        }
        self = migrated
    }

    private static func migratingLegacyRawValue(_ value: String) -> RecipeFramework? {
        switch value {
        case "salad", "bowl": .bowls
        case "stirFry": .sautes
        case "soup": .soups
        case "braise": .braises
        case "sandwich": .handhelds
        default: nil
        }
    }
}
