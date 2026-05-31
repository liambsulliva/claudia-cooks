//
//  IngredientCategory+Style.swift
//  claudia-cooks
//

import SwiftUI

extension IngredientCategory {
    var accentColor: Color {
        switch self {
        case .protein: Color(red: 0.88, green: 0.42, blue: 0.38)
        case .carbs: Color(red: 0.93, green: 0.72, blue: 0.28)
        case .produce: Color(red: 0.36, green: 0.72, blue: 0.46)
        case .dairy: Color(red: 0.96, green: 0.78, blue: 0.34)
        case .fats: Color(red: 0.98, green: 0.62, blue: 0.22)
        case .aromatics: Color(red: 0.58, green: 0.48, blue: 0.86)
        case .spices: Color(red: 0.52, green: 0.68, blue: 0.32)
        case .acids: Color(red: 0.95, green: 0.55, blue: 0.18)
        case .liquids: Color(red: 0.28, green: 0.62, blue: 0.78)
        case .enhancers: Color(red: 0.72, green: 0.38, blue: 0.48)
        }
    }
}
