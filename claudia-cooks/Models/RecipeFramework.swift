//
//  RecipeFramework.swift
//  claudia-cooks
//

import Foundation

enum RecipeFramework: String, CaseIterable, Codable, Identifiable, Sendable {
    case salad
    case stirFry
    case bowl
    case soup
    case braise
    case sandwich

    var id: String { rawValue }

    var title: String {
        switch self {
        case .salad: "Salad"
        case .stirFry: "Stir-Fry"
        case .bowl: "Bowl"
        case .soup: "Soup"
        case .braise: "Braise"
        case .sandwich: "Sandwich"
        }
    }

    var tagline: String {
        switch self {
        case .salad: "Fresh, crisp, and bright"
        case .stirFry: "Fast heat, bold flavors"
        case .bowl: "Balanced layers in one dish"
        case .soup: "Comfort in every spoonful"
        case .braise: "Low and slow until tender"
        case .sandwich: "Stacked, handheld, satisfying"
        }
    }

    var icon: String {
        switch self {
        case .salad: "leaf.fill"
        case .stirFry: "flame.fill"
        case .bowl: "circle.grid.2x2.fill"
        case .soup: "mug.fill"
        case .braise: "hourglass.bottomhalf.filled"
        case .sandwich: "square.stack.3d.up.fill"
        }
    }

    var applicableCategories: [IngredientCategory] {
        switch self {
        case .salad:
            [.protein, .produce, .dairy, .fats, .aromatics, .spices, .acids, .enhancers]
        case .stirFry:
            [.protein, .carbs, .produce, .fats, .aromatics, .spices, .acids, .liquids, .enhancers]
        case .soup, .braise:
            [.protein, .carbs, .produce, .dairy, .fats, .aromatics, .spices, .acids, .liquids, .enhancers]
        case .bowl, .sandwich:
            IngredientCategory.allCases
        }
    }
}
