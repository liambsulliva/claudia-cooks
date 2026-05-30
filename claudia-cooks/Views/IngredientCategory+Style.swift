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
        case .veg: Color(red: 0.36, green: 0.72, blue: 0.46)
        case .cheese: Color(red: 0.96, green: 0.78, blue: 0.34)
        case .aromatics: Color(red: 0.58, green: 0.48, blue: 0.86)
        case .sauces: Color(red: 0.28, green: 0.62, blue: 0.78)
        }
    }
}
