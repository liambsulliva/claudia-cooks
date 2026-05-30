//
//  MLXSetupViewModel.swift
//  claudia-cooks
//

import Foundation
import Observation

@MainActor
@Observable
final class MLXSetupViewModel {
    var showModelSetupSheet = false
    var modelSetupTier: MLXModelTier = .fast
    var isPullingModel = false
    var modelPullProgress: MLXModelDownloadProgress?
    var modelPullError: String?
    var modelAvailability: String?

    @ObservationIgnored private let generationService: RecipeGenerationService
    @ObservationIgnored private var userDismissedModelSetup = false
    @ObservationIgnored var onModelReady: (() -> Void)?

    init(generationService: RecipeGenerationService) {
        self.generationService = generationService
        self.modelSetupTier = generationService.recommendedSetupTier
    }

    func refreshAvailability() async {
        let status = await generationService.refreshAvailability()
        modelAvailability = generationService.lastAvailabilityMessage

        switch status {
        case .ready:
            showModelSetupSheet = false
            modelPullError = nil
            userDismissedModelSetup = false
        case .modelNotDownloaded:
            modelSetupTier = generationService.recommendedSetupTier
            if !userDismissedModelSetup {
                showModelSetupSheet = true
            }
        }
    }

    func cancelModelSetup() {
        userDismissedModelSetup = true
        showModelSetupSheet = false
        modelPullError = nil
        modelPullProgress = nil
    }

    func presentModelSetup() {
        userDismissedModelSetup = false
        modelSetupTier = generationService.recommendedSetupTier
        modelPullError = nil
        modelPullProgress = nil
        showModelSetupSheet = true
    }

    func downloadSelectedModel() {
        guard !isPullingModel else {
            return
        }

        modelPullError = nil
        modelPullProgress = .starting
        isPullingModel = true

        let tier = modelSetupTier

        Task {
            do {
                try await generationService.downloadModel(tier: tier) { [weak self] progress in
                    Task { @MainActor in
                        self?.modelPullProgress = progress
                    }
                }

                isPullingModel = false
                modelPullProgress = nil
                showModelSetupSheet = false
                await refreshAvailability()
                onModelReady?()
            } catch {
                isPullingModel = false
                modelPullError = error.localizedDescription
            }
        }
    }
}
