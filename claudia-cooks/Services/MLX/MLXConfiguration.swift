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

    func resolvedModel(for load: MLXSystemLoad, preferredTier: MLXModelTier?) -> String {
        if let preferredTier {
            return preferredTier.modelName
        }

        return load.shouldUseLowMemoryMode ? lowMemoryModel : defaultModel
    }

    func repoID(for modelName: String) throws -> Repo.ID {
        guard let repoID = Repo.ID(rawValue: modelName) else {
            throw MLXClientError.invalidModelIdentifier(modelName)
        }

        return repoID
    }
}
