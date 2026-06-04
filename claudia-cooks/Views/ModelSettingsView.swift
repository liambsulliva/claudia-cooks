//
//  ModelSettingsView.swift
//  claudia-cooks
//

import SwiftUI

struct ModelSettingsView: View {
    @State private var viewModel = MLXModelSettingsViewModel()

    var body: some View {
        @Bindable var viewModel = viewModel

        Form {
            Section("Active Model") {
                Text("Choose the MLX model Claudia uses for on-device recipe generation.")
                    .foregroundStyle(.secondary)

                Picker("Use model", selection: selectedModelBinding) {
                    ForEach(viewModel.modelItems) { item in
                        Text(item.displayName).tag(item.modelName)
                    }
                }
                .pickerStyle(.menu)
                .disabled(viewModel.isBusy || viewModel.modelItems.isEmpty)

                if let selectedItem = viewModel.selectedItem {
                    modelSummary(selectedItem)
                }
            }

            Section("Installed Models") {
                Text("Download missing models or remove local model files. Claudia keeps at least one downloaded model available.")
                    .foregroundStyle(.secondary)

                if viewModel.isRefreshing && viewModel.modelItems.isEmpty {
                    ProgressView("Checking installed models...")
                } else {
                    ForEach(viewModel.modelItems) { item in
                        modelRow(item)
                    }
                }
            }

            Section("Custom Hugging Face Models") {
                Text("Add MLX-compatible Hugging Face repositories, then download and select them like the built-in models.")
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    TextField("organization/model-name", text: $viewModel.customModelDraft)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(viewModel.addCustomModel)

                    Button("Add Model", action: viewModel.addCustomModel)
                        .disabled(
                            viewModel.customModelDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || viewModel.isBusy
                        )
                }
            }

            if let modelActionError = viewModel.modelActionError {
                Section {
                    Label(modelActionError, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
        }
        .formStyle(.grouped)
        .padding(24)
        .task {
            await viewModel.refreshAvailability()
        }
    }

    private var selectedModelBinding: Binding<String> {
        Binding(
            get: { viewModel.selectedModelName },
            set: { viewModel.selectModel(named: $0) }
        )
    }

    private func modelSummary(_ item: MLXModelSettingsItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.modelName)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            if item.isDownloaded {
                Label("Downloaded and ready to use", systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.green)
            } else {
                Label("Download this model before generating recipes with it", systemImage: "arrow.down.circle")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func modelRow(_ item: MLXModelSettingsItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(item.displayName)
                            .font(.headline)

                        if item.modelName == viewModel.selectedModelName {
                            Text("Selected")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(.tint.opacity(0.14), in: Capsule())
                                .foregroundStyle(.tint)
                        }

                        if item.isCustom {
                            Text("Custom")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(.secondary.opacity(0.12), in: Capsule())
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(item.detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Text(item.modelName)
                        .font(.caption.monospaced())
                        .foregroundStyle(.tertiary)
                        .textSelection(.enabled)

                    modelStatus(item)
                }

                Spacer(minLength: 16)

                modelActions(item)
            }

            if viewModel.activeDownloadModelName == item.modelName {
                downloadProgressView
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func modelStatus(_ item: MLXModelSettingsItem) -> some View {
        if item.isDownloaded {
            Label("Downloaded", systemImage: "checkmark.circle.fill")
                .font(.callout)
                .foregroundStyle(.green)
        } else {
            Label("Not downloaded", systemImage: "icloud.and.arrow.down")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func modelActions(_ item: MLXModelSettingsItem) -> some View {
        VStack(alignment: .trailing, spacing: 8) {
            if item.isDownloaded {
                Button("Remove", role: .destructive) {
                    viewModel.removeDownloadedModel(named: item.modelName)
                }
                .disabled(!viewModel.canRemoveDownloadedModel(named: item.modelName) || viewModel.isBusy)
            } else {
                Button("Download") {
                    viewModel.downloadModel(named: item.modelName)
                }
                .disabled(viewModel.isBusy)
            }

            if item.isCustom && !item.isDownloaded {
                Button("Forget") {
                    viewModel.forgetCustomModel(named: item.modelName)
                }
                .disabled(viewModel.isBusy)
            }
        }
        .controlSize(.small)
    }

    @ViewBuilder
    private var downloadProgressView: some View {
        if let downloadProgress = viewModel.downloadProgress {
            if let fraction = downloadProgress.fraction {
                ProgressView(value: fraction) {
                    Text(downloadProgress.status)
                } currentValueLabel: {
                    if let percent = downloadProgress.percentComplete {
                        Text("\(percent)%")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                ProgressView(downloadProgress.status)
            }

            Text(downloadProgress.detailLine)
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            ProgressView("Starting download...")
        }
    }
}

#Preview {
    ModelSettingsView()
}
