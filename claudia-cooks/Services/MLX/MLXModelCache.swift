//
//  MLXModelCache.swift
//  claudia-cooks
//

import Foundation
import HuggingFace
import MLXLLM
import MLXLMCommon

actor MLXModelCache {
    static let shared = MLXModelCache()

    private var loadedModelName: String?
    private var loadedContainer: ModelContainer?

    func container(
        modelName: String,
        configuration: MLXConfiguration,
        progressHandler: (@Sendable (MLXModelDownloadProgress) -> Void)?
    ) async throws -> ModelContainer {
        if loadedModelName == modelName, let loadedContainer {
            return loadedContainer
        }

        progressHandler?(.starting)

        let repoID = try configuration.repoID(for: modelName)
        let modelDirectory = try await HubClient.default.downloadSnapshot(
            of: repoID,
            revision: "main",
            matching: configuration.downloadPatterns,
            progressHandler: { @MainActor progress in
                progressHandler?(.downloading(progress))
            }
        )
        progressHandler?(.loading)

        let container = try await LLMModelFactory.shared.loadContainer(
            from: modelDirectory,
            using: TransformersTokenizerLoader()
        )

        loadedModelName = modelName
        loadedContainer = container
        return container
    }
}
