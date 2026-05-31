//
//  IngredientCategory.swift
//  claudia-cooks
//

import Foundation

enum IngredientCategory: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
    case protein
    case carbs
    case produce
    case dairy
    case fats
    case aromatics
    case spices
    case acids
    case liquids
    case enhancers

    var id: String { rawValue }

    var title: String {
        switch self {
        case .protein: "Protein"
        case .carbs: "Carbs/Starch"
        case .produce: "Produce"
        case .dairy: "Dairy"
        case .fats: "Fat Sources"
        case .aromatics: "Aromatics"
        case .spices: "Spices/Herbs"
        case .acids: "Acids/Citrus"
        case .liquids: "Liquids/Bases"
        case .enhancers: "Flavor Enhancers"
        }
    }

    var promptLabel: String {
        switch self {
        case .protein: "Protein"
        case .carbs: "Carbs and starch"
        case .produce: "Produce"
        case .dairy: "Dairy"
        case .fats: "Fat sources"
        case .aromatics: "Aromatics"
        case .spices: "Spices and herbs"
        case .acids: "Acids and citrus"
        case .liquids: "Liquids and bases"
        case .enhancers: "Flavor enhancers"
        }
    }

    var icon: String {
        switch self {
        case .protein: "fish.fill"
        case .carbs: "circle.hexagongrid.fill"
        case .produce: "carrot.fill"
        case .dairy: "square.fill"
        case .fats: "drop.fill"
        case .aromatics: "sparkles"
        case .spices: "leaf.fill"
        case .acids: "drop.triangle.fill"
        case .liquids: "mug.fill"
        case .enhancers: "flask.fill"
        }
    }

    /// Resolves persisted selection keys and legacy classifier labels.
    init?(storageKey: String) {
        let normalized = storageKey.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let category = IngredientCategory(rawValue: normalized) {
            self = category
            return
        }

        switch normalized {
        case "veg", "vegetables", "vegetable":
            self = .produce
        case "cheese":
            self = .dairy
        case "sauces", "sauce", "condiments":
            self = .enhancers
        case "starch", "carbs_starch", "carb":
            self = .carbs
        case "fat", "oil", "oils":
            self = .fats
        case "herbs", "spice", "dried_herbs":
            self = .spices
        case "acid", "citrus", "vinegar":
            self = .acids
        case "liquid", "broth", "wine", "base", "bases":
            self = .liquids
        case "umami", "flavor_enhancers", "flavor_enhancer", "enhancer":
            self = .enhancers
        default:
            return nil
        }
    }
}
