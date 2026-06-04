//
//  MLXConfiguration.swift
//  claudia-cooks
//

import Foundation
import HuggingFace

struct MLXConfiguration: Sendable {
    static let shared = MLXConfiguration()

    let defaultModel = "mlx-community/Qwen3-1.7B-4bit"
    let lowMemoryModel = "mlx-community/Qwen3-0.6B-4bit"
    let lowMemoryPhysicalThresholdBytes: UInt64 = 8 * 1024 * 1024 * 1024
    let lowMemoryAvailableThresholdBytes: UInt64 = 1_500_000_000

    let downloadPatterns = ["*.safetensors", "*.json", "*.jinja"]

    var builtInModelNames: [String] {
        [defaultModel, lowMemoryModel]
    }

    func resolvedModel(for load: MLXSystemLoad, preferredTier: MLXModelTier?) -> String {
        resolvedModel(for: load, preferredModelName: preferredTier?.modelName)
    }

    func resolvedModel(for load: MLXSystemLoad, preferredModelName: String?) -> String {
        if let preferredModelName {
            return preferredModelName
        }

        return defaultModel(for: load)
    }

    func defaultModel(for load: MLXSystemLoad) -> String {
        load.shouldUseLowMemoryMode ? lowMemoryModel : defaultModel
    }

    func alternateBuiltInModelName(for modelName: String) -> String? {
        guard builtInModelNames.contains(modelName) else {
            return nil
        }

        if modelName == lowMemoryModel {
            return defaultModel
        } else {
            return lowMemoryModel
        }
    }

    func repoID(for modelName: String) throws -> Repo.ID {
        guard let repoID = Repo.ID(rawValue: modelName) else {
            throw MLXClientError.invalidModelIdentifier(modelName)
        }

        return repoID
    }
}
