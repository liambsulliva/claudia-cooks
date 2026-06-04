//
//  RecipeGenerationLanguagePreferenceStore.swift
//  claudia-cooks
//

import Foundation

enum RecipeGenerationLanguagePreferenceStore: Sendable {
    private static let userDefaultsKey = "preferredRecipeGenerationLanguage"

    static var preferredLanguage: RecipeGenerationLanguage {
        get {
            guard let raw = UserDefaults.standard.string(forKey: userDefaultsKey),
                  let language = RecipeGenerationLanguage(rawValue: raw) else {
                return .default
            }

            return language
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: userDefaultsKey)
        }
    }
}
