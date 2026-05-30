//
//  MLXModelPreferenceStore.swift
//  claudia-cooks
//

import Foundation

enum MLXModelPreferenceStore: Sendable {
    private static let userDefaultsKey = "mlxPreferredModelTier"

    static var preferredTier: MLXModelTier? {
        get {
            guard let raw = UserDefaults.standard.string(forKey: userDefaultsKey) else {
                return nil
            }

            return MLXModelTier(rawValue: raw)
        }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue.rawValue, forKey: userDefaultsKey)
            } else {
                UserDefaults.standard.removeObject(forKey: userDefaultsKey)
            }
        }
    }
}
