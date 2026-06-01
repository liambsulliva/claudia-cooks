//
//  RecipeFramework+Style.swift
//  claudia-cooks
//

import SwiftUI

extension RecipeFramework {
    var accentColor: Color {
        switch self {
        case .handhelds: Color(red: 0.82, green: 0.62, blue: 0.35)
        case .bowls: Color(red: 0.35, green: 0.72, blue: 0.45)
        case .soups: Color(red: 0.92, green: 0.65, blue: 0.28)
        case .sautes: Color(red: 0.95, green: 0.45, blue: 0.25)
        case .braises: Color(red: 0.72, green: 0.38, blue: 0.32)
        case .bakes: Color(red: 0.55, green: 0.45, blue: 0.85)
        }
    }
}
