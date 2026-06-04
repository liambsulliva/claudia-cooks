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

    func isModelDownloaded(
        modelName: String,
        configuration: MLXConfiguration
    ) async -> Bool {
        do {
            _ = try await localModelDirectory(modelName: modelName, configuration: configuration)
            return true
        } catch {
            return false
        }
    }

    func removeModel(
        modelName: String,
        configuration: MLXConfiguration
    ) async throws -> Bool {
        let modelDirectory: URL
        do {
            modelDirectory = try await localModelDirectory(modelName: modelName, configuration: configuration)
        } catch {
            return false
        }

        if loadedModelName == modelName {
            loadedModelName = nil
            loadedContainer = nil
        }

        let removalURL = cacheDirectoryToRemove(containing: modelDirectory)
        try FileManager.default.removeItem(at: removalURL)
        return true
    }

    private func localModelDirectory(
        modelName: String,
        configuration: MLXConfiguration
    ) async throws -> URL {
        let repoID = try configuration.repoID(for: modelName)
        return try await HubClient.default.downloadSnapshot(
            of: repoID,
            revision: "main",
            matching: configuration.downloadPatterns,
            localFilesOnly: true,
            maxConcurrentDownloads: 1
        )
    }

    private func cacheDirectoryToRemove(containing modelDirectory: URL) -> URL {
        let snapshotDirectory = modelDirectory.deletingLastPathComponent()
        let repositoryDirectory = snapshotDirectory.deletingLastPathComponent()

        if snapshotDirectory.lastPathComponent == "snapshots",
           repositoryDirectory.lastPathComponent.hasPrefix("models--") {
            return repositoryDirectory
        }

        return modelDirectory
    }
}
