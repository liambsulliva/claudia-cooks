//
//  RecipeFramework.swift
//  recipe-app
//

import SwiftUI

enum RecipeFramework: String, CaseIterable, Identifiable {
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

    var accentColor: Color {
        switch self {
        case .salad: Color(red: 0.35, green: 0.72, blue: 0.45)
        case .stirFry: Color(red: 0.95, green: 0.45, blue: 0.25)
        case .bowl: Color(red: 0.55, green: 0.45, blue: 0.85)
        case .soup: Color(red: 0.92, green: 0.65, blue: 0.28)
        case .braise: Color(red: 0.72, green: 0.38, blue: 0.32)
        case .sandwich: Color(red: 0.82, green: 0.62, blue: 0.35)
        }
    }
}
