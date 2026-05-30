//
//  RecipeFramework+AppKit.swift
//  claudia-cooks
//

import AppKit

extension RecipeFramework {
    var nsAccentColor: NSColor {
        switch self {
        case .salad: NSColor(red: 0.35, green: 0.72, blue: 0.45, alpha: 1)
        case .stirFry: NSColor(red: 0.95, green: 0.45, blue: 0.25, alpha: 1)
        case .bowl: NSColor(red: 0.55, green: 0.45, blue: 0.85, alpha: 1)
        case .soup: NSColor(red: 0.92, green: 0.65, blue: 0.28, alpha: 1)
        case .braise: NSColor(red: 0.72, green: 0.38, blue: 0.32, alpha: 1)
        case .sandwich: NSColor(red: 0.82, green: 0.62, blue: 0.35, alpha: 1)
        }
    }
}
