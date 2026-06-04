//
//  CookingMeasurementPreferenceStore.swift
//  claudia-cooks
//

import Foundation

enum CookingMeasurementPreferenceStore: Sendable {
    private static let userDefaultsKey = "preferredCookingMeasurementSystem"

    static var preferredSystem: CookingMeasurementSystem? {
        get {
            guard let raw = UserDefaults.standard.string(forKey: userDefaultsKey) else {
                return nil
            }

            return CookingMeasurementSystem(rawValue: raw)
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
