//
//  RecipeBadgeID.swift
//  claudia-cooks
//

import Foundation

enum RecipeBadgeID {
    static func selection(_ index: Int) -> String { "selection-\(index)" }
    static func ingredient(_ index: Int) -> String { "ingredient-\(index)" }
    static func step(_ index: Int) -> String { "step-\(index)" }
    static func tip(_ index: Int) -> String { "tip-\(index)" }
}
