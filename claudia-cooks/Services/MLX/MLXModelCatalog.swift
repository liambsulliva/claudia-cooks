//
//  MLXModelCatalog.swift
//  claudia-cooks
//

import Foundation

struct MLXModelOption: Identifiable, Equatable, Sendable {
    enum Source: Equatable, Sendable {
        case builtIn(MLXModelTier)
        case custom
    }

    let modelName: String
    let displayName: String
    let detail: String
    let source: Source

    var id: String { modelName }

    var isCustom: Bool {
        if case .custom = source {
            return true
        }
        return false
    }

    static var builtInOptions: [MLXModelOption] {
        MLXModelTier.allCases.map { tier in
            MLXModelOption(
                modelName: tier.modelName,
                displayName: tier.settingsTitle,
                detail: tier.settingsDetail,
                source: .builtIn(tier)
            )
        }
    }

    static func custom(modelName: String) -> MLXModelOption {
        MLXModelOption(
            modelName: modelName,
            displayName: customDisplayName(for: modelName),
            detail: "Custom Hugging Face model repository.",
            source: .custom
        )
    }

    private static func customDisplayName(for modelName: String) -> String {
        let components = modelName.split(separator: "/")
        guard let last = components.last else {
            return modelName
        }
        return String(last)
    }
}

enum MLXModelCatalog {
    static var allOptions: [MLXModelOption] {
        MLXModelOption.builtInOptions
            + MLXModelPreferenceStore.customModelNames.map(MLXModelOption.custom)
    }

    static func option(for modelName: String) -> MLXModelOption {
        allOptions.first { $0.modelName == modelName }
            ?? MLXModelOption.custom(modelName: modelName)
    }
}
