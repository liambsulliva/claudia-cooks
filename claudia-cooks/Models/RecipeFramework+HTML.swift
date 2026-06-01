//
//  RecipeFramework+HTML.swift
//  claudia-cooks
//

import Foundation

extension RecipeFramework {
    var htmlAccentHex: String {
        switch self {
        case .handhelds: "#D19E59"
        case .bowls: "#59B873"
        case .soups: "#EBA647"
        case .sautes: "#F27340"
        case .braises: "#B86152"
        case .bakes: "#8C73D9"
        }
    }
}
