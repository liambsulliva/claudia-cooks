//
//  IngredientCategory.swift
//  claudia-cooks
//

import Foundation

enum IngredientCategory: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
    case protein
    case carbs
    case veg
    case cheese
    case aromatics
    case sauces

    var id: String { rawValue }

    var title: String {
        switch self {
        case .protein: "Protein"
        case .carbs: "Carbs"
        case .veg: "Veg"
        case .cheese: "Cheese"
        case .aromatics: "Aromatics"
        case .sauces: "Sauces"
        }
    }

    var promptLabel: String {
        switch self {
        case .protein: "Protein"
        case .carbs: "Carbs"
        case .veg: "Vegetables"
        case .cheese: "Cheese"
        case .aromatics: "Aromatics"
        case .sauces: "Sauces"
        }
    }

    var icon: String {
        switch self {
        case .protein: "fish.fill"
        case .carbs: "leaf.circle.fill"
        case .veg: "carrot.fill"
        case .cheese: "square.fill"
        case .aromatics: "sparkles"
        case .sauces: "drop.fill"
        }
    }
}
