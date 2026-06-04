//
//  MLXModelSettingsViewModel.swift
//  claudia-cooks
//

import Foundation
import Observation

struct MLXModelSettingsItem: Identifiable, Equatable {
    let option: MLXModelOption
    var isDownloaded: Bool

    var id: String { option.id }
    var modelName: String { option.modelName }
    var displayName: String { option.displayName }
    var detail: String { option.detail }
    var isCustom: Bool { option.isCustom }
}

@MainActor
@Observable
final class MLXModelSettingsViewModel {
    var modelItems: [MLXModelSettingsItem] = []
    var selectedModelName: String
    var customModelDraft = ""
    var isRefreshing = false
    var activeDownloadModelName: String?
    var activeRemovalModelName: String?
    var downloadProgress: MLXModelDownloadProgress?
    var modelActionError: String?

    @ObservationIgnored private let mlx = MLXClient()
    @ObservationIgnored private let configuration = MLXConfiguration.shared

    init() {
        selectedModelName = MLXModelPreferenceStore.preferredModelName
            ?? configuration.defaultModel(for: .current())
    }

    var isBusy: Bool {
        activeDownloadModelName != nil || activeRemovalModelName != nil
    }

    var installedModelCount: Int {
        modelItems.filter(\.isDownloaded).count
    }

    var selectedItem: MLXModelSettingsItem? {
        modelItems.first { $0.modelName == selectedModelName }
    }

    func refreshAvailability() async {
        isRefreshing = true

        let options = MLXModelCatalog.allOptions
        let downloaded = await mlx.downloadedModels(in: options.map(\.modelName))
        modelItems = options.map { option in
            MLXModelSettingsItem(
                option: option,
                isDownloaded: downloaded.contains(option.modelName)
            )
        }

        reconcileSelectedModel()
        isRefreshing = false
    }

    func selectModel(named modelName: String) {
        guard let normalized = MLXModelPreferenceStore.normalizedModelName(modelName) else {
            return
        }

        selectedModelName = normalized
        MLXModelPreferenceStore.preferredModelName = normalized
        modelActionError = nil
    }

    func addCustomModel() {
        let draft = customModelDraft
        guard let normalized = MLXModelPreferenceStore.normalizedModelName(draft) else {
            modelActionError = "Enter a Hugging Face model ID like organization/model-name."
            return
        }

        do {
            _ = try configuration.repoID(for: normalized)
        } catch {
            modelActionError = error.localizedDescription
            return
        }

        if MLXModelTier.tier(forModelName: normalized) == nil {
            _ = MLXModelPreferenceStore.addCustomModelName(normalized)
        }

        customModelDraft = ""
        selectModel(named: normalized)

        Task {
            await refreshAvailability()
        }
    }

    func downloadModel(named modelName: String) {
        guard !isBusy else {
            return
        }

        activeDownloadModelName = modelName
        downloadProgress = .starting
        modelActionError = nil

        Task {
            do {
                try await mlx.downloadModel(modelName) { [weak self] progress in
                    Task { @MainActor in
                        self?.downloadProgress = progress
                    }
                }

                selectModel(named: modelName)
                activeDownloadModelName = nil
                downloadProgress = nil
                await refreshAvailability()
            } catch {
                activeDownloadModelName = nil
                downloadProgress = nil
                modelActionError = error.localizedDescription
            }
        }
    }

    func removeDownloadedModel(named modelName: String) {
        guard !isBusy else {
            return
        }

        guard canRemoveDownloadedModel(named: modelName) else {
            modelActionError = "Keep at least one downloaded model available."
            return
        }

        activeRemovalModelName = modelName
        modelActionError = nil

        let fallbackModelName = modelItems.first {
            $0.modelName != modelName && $0.isDownloaded
        }?.modelName

        Task {
            do {
                _ = try await mlx.removeDownloadedModel(modelName)

                if selectedModelName == modelName, let fallbackModelName {
                    selectModel(named: fallbackModelName)
                }

                activeRemovalModelName = nil
                await refreshAvailability()
            } catch {
                activeRemovalModelName = nil
                modelActionError = error.localizedDescription
            }
        }
    }

    func forgetCustomModel(named modelName: String) {
        guard let item = modelItems.first(where: { $0.modelName == modelName }),
              item.isCustom else {
            return
        }

        guard !item.isDownloaded else {
            modelActionError = "Remove this model's downloaded files before forgetting it."
            return
        }

        MLXModelPreferenceStore.removeCustomModelName(modelName)
        if selectedModelName == modelName {
            selectedModelName = MLXModelPreferenceStore.preferredModelName
                ?? modelItems.first { !$0.isCustom }?.modelName
                ?? configuration.defaultModel(for: .current())
        }
        modelActionError = nil

        Task {
            await refreshAvailability()
        }
    }

    func canRemoveDownloadedModel(named modelName: String) -> Bool {
        guard modelItems.contains(where: { $0.modelName == modelName && $0.isDownloaded }) else {
            return false
        }

        return installedModelCount > 1
    }

    private func reconcileSelectedModel() {
        if !modelItems.contains(where: { $0.modelName == selectedModelName }) {
            selectedModelName = MLXModelPreferenceStore.preferredModelName
                ?? configuration.defaultModel(for: .current())
        }
    }
}
