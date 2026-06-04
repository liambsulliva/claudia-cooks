//
//  MLXModelPreferenceStore.swift
//  claudia-cooks
//

import Foundation

enum MLXModelPreferenceStore: Sendable {
    private static let preferredTierKey = "mlxPreferredModelTier"
    private static let preferredModelNameKey = "mlxPreferredModelName"
    private static let customModelNamesKey = "mlxCustomModelNames"

    static var preferredTier: MLXModelTier? {
        get {
            if let preferredModelName {
                return MLXModelTier.tier(forModelName: preferredModelName)
            }

            guard let raw = UserDefaults.standard.string(forKey: preferredTierKey) else {
                return nil
            }
            return MLXModelTier(rawValue: raw)
        }
        set {
            if let newValue {
                preferredModelName = newValue.modelName
                UserDefaults.standard.set(newValue.rawValue, forKey: preferredTierKey)
            } else {
                preferredModelName = nil
                UserDefaults.standard.removeObject(forKey: preferredTierKey)
            }
        }
    }

    static var preferredModelName: String? {
        get {
            if let modelName = normalizedModelName(
                UserDefaults.standard.string(forKey: preferredModelNameKey)
            ) {
                return modelName
            }

            guard let raw = UserDefaults.standard.string(forKey: preferredTierKey),
                  let tier = MLXModelTier(rawValue: raw) else {
                return nil
            }

            return tier.modelName
        }
        set {
            guard let modelName = normalizedModelName(newValue) else {
                UserDefaults.standard.removeObject(forKey: preferredModelNameKey)
                UserDefaults.standard.removeObject(forKey: preferredTierKey)
                return
            }

            UserDefaults.standard.set(modelName, forKey: preferredModelNameKey)

            if let tier = MLXModelTier.tier(forModelName: modelName) {
                UserDefaults.standard.set(tier.rawValue, forKey: preferredTierKey)
            } else {
                UserDefaults.standard.removeObject(forKey: preferredTierKey)
            }
        }
    }

    static var hasExplicitPreferredModel: Bool {
        preferredModelName != nil
    }

    static var customModelNames: [String] {
        get {
            guard let data = UserDefaults.standard.data(forKey: customModelNamesKey),
                  let decoded = try? JSONDecoder().decode([String].self, from: data) else {
                return []
            }

            return uniqueModelNames(decoded)
        }
        set {
            let normalized = uniqueModelNames(newValue)
            if normalized.isEmpty {
                UserDefaults.standard.removeObject(forKey: customModelNamesKey)
                return
            }

            if let data = try? JSONEncoder().encode(normalized) {
                UserDefaults.standard.set(data, forKey: customModelNamesKey)
            }
        }
    }

    @discardableResult
    static func addCustomModelName(_ modelName: String) -> String? {
        guard let normalized = normalizedModelName(modelName) else {
            return nil
        }

        var names = customModelNames
        if !names.contains(normalized) {
            names.append(normalized)
            customModelNames = names
        }
        return normalized
    }

    static func removeCustomModelName(_ modelName: String) {
        guard let normalized = normalizedModelName(modelName) else {
            return
        }

        customModelNames = customModelNames.filter { $0 != normalized }
        if preferredModelName == normalized {
            preferredModelName = nil
        }
    }

    static func normalizedModelName(_ modelName: String?) -> String? {
        guard let modelName else {
            return nil
        }

        let trimmed = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func uniqueModelNames(_ modelNames: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []

        for modelName in modelNames {
            guard let normalized = normalizedModelName(modelName),
                  !seen.contains(normalized),
                  MLXModelTier.tier(forModelName: normalized) == nil else {
                continue
            }

            seen.insert(normalized)
            result.append(normalized)
        }

        return result
    }
}
