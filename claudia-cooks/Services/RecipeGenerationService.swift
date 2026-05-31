//
//  RecipeGenerationService.swift
//  claudia-cooks
//

import Foundation

@MainActor
final class RecipeGenerationService {
    private let mlx = MLXClient()

    private(set) var lastAvailability: MLXAvailability?
    private(set) var lastAvailabilityMessage: String?

    var recommendedSetupTier: MLXModelTier {
        MLXClient.recommendedTier()
    }

    @discardableResult
    func refreshAvailability() async -> MLXAvailability {
        let status = await mlx.availability()
        lastAvailability = status
        lastAvailabilityMessage = message(for: status)
        return status
    }

    func availability() async -> MLXAvailability {
        if let lastAvailability {
            return lastAvailability
        }

        return await refreshAvailability()
    }

    var availabilityMessage: String? {
        get async {
            if let lastAvailabilityMessage {
                return lastAvailabilityMessage
            }

            _ = await refreshAvailability()
            return lastAvailabilityMessage
        }
    }

    func downloadModel(
        tier: MLXModelTier,
        progress: (@Sendable (MLXModelDownloadProgress) -> Void)? = nil
    ) async throws {
        MLXModelPreferenceStore.preferredTier = tier
        try await mlx.downloadModel(tier.modelName, progressHandler: progress)
        _ = await refreshAvailability()
    }

    func generateRecipe(
        framework: RecipeFramework,
        selections: RecipeSelections,
        onPartialResponse: (@Sendable (GeneratedRecipe) -> Void)? = nil
    ) async throws -> GeneratedRecipe {
        if lastAvailability == nil {
            _ = await refreshAvailability()
        }

        switch lastAvailability {
        case .ready:
            break
        case .modelNotDownloaded, .none:
            if let message = lastAvailabilityMessage {
                throw RecipeGenerationError.unavailable(message)
            }
        }

        do {
            return try await mlx.generateRecipe(
                framework: framework,
                selections: selections,
                onPartialResponse: onPartialResponse
            )
        } catch let error as MLXClientError {
            throw RecipeGenerationError.mlx(error)
        }
    }

    private func message(for status: MLXAvailability) -> String? {
        switch status {
        case .ready:
            nil
        case .modelNotDownloaded(let missingModel):
            """
            \(missingModel) is not downloaded yet. \
            Choose an MLX model size to download and keep the preview on your current selections until it is ready.
            """
        }
    }
}

enum RecipeGenerationError: LocalizedError {
    case unavailable(String)
    case mlx(MLXClientError)

    var errorDescription: String? {
        switch self {
        case .unavailable(let message):
            message
        case .mlx(let error):
            error.localizedDescription
        }
    }
}
