//
//  RecipeFramework+HTML.swift
//  claudia-cooks
//

import Foundation

extension RecipeFramework {
    var htmlAccentHex: String {
        switch self {
        case .salad: "#59B873"
        case .stirFry: "#F27340"
        case .bowl: "#8C73D9"
        case .soup: "#EBA647"
        case .braise: "#B86152"
        case .sandwich: "#D19E59"
        }
    }
}
