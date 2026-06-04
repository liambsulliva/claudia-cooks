//
//  MacroCalculationsPreferenceStore.swift
//  claudia-cooks
//

import Foundation

enum MacroCalculationsPreferenceStore: Sendable {
    private static let userDefaultsKey = "macroCalculationsEnabled"

    static var isEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: userDefaultsKey) == nil {
                return true
            }

            return UserDefaults.standard.bool(forKey: userDefaultsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: userDefaultsKey)
        }
    }
}
