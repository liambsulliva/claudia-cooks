//
//  MLXModelSetupSheet.swift
//  claudia-cooks
//

import SwiftUI

struct MLXModelSetupSheet: View {
    @Binding var selectedTier: MLXModelTier
    let isDownloading: Bool
    let downloadProgress: MLXModelDownloadProgress?
    let downloadError: String?
    let onDownload: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Download an MLX Recipe Model")
                .font(.title2.weight(.semibold))

            Text(
                """
                MLX runs local inference directly on Apple Silicon. Choose which fast Qwen model \
                size to download for on-device recipe generation.
                """
            )
            .font(.body)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            Text(
                """
                The model is cached in the app's Hugging Face cache. Pick 1.7B for the best \
                balance of speed and quality, or 0.6B when you want the fastest updates.
                """
            )
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            if isDownloading {
                downloadingSection
            } else {
                longDownloadNotice
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(MLXModelTier.allCases) { tier in
                    Toggle(isOn: isSelected(tier)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tier.checkboxLabel)
                            Text(tier.checklistDetail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .disabled(isDownloading)
                }
            }
            .padding(.leading, 4)

            if let downloadError {
                Label(downloadError, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                    .disabled(isDownloading)

                Button(isDownloading ? "Downloading..." : "Download", action: onDownload)
                    .keyboardShortcut(.defaultAction)
                    .disabled(isDownloading)
            }
        }
        .padding(28)
        .frame(width: 500)
    }

    private var longDownloadNotice: some View {
        Label {
            Text(
                """
                Downloading the MLX weights can take a few minutes depending on your connection. \
                The 0.6B model is under 400 MB; the 1.7B model is about 1 GB. Leave this window \
                open until the model finishes downloading and loading.
                """
            )
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "clock.badge.exclamationmark")
                .foregroundStyle(.orange)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private var downloadingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text(
                    """
                    MLX is downloading model files from Hugging Face, then loading the model \
                    into memory for local generation.
                    """
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "arrow.down.circle")
                    .foregroundStyle(.tint)
            }

            if let downloadProgress {
                if let fraction = downloadProgress.fraction {
                    ProgressView(value: fraction) {
                        Text(downloadProgress.status)
                            .font(.callout.weight(.medium))
                    } currentValueLabel: {
                        if let percent = downloadProgress.percentComplete {
                            Text("\(percent)%")
                                .font(.callout.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .progressViewStyle(.linear)
                } else {
                    ProgressView(downloadProgress.status)
                        .progressViewStyle(.linear)
                }

                HStack {
                    Text(downloadProgress.detailLine)
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Spacer()

                    if downloadProgress.fraction == nil {
                        Text("Preparing...")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            } else {
                ProgressView("Starting download...")
                    .progressViewStyle(.linear)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func isSelected(_ tier: MLXModelTier) -> Binding<Bool> {
        Binding(
            get: { selectedTier == tier },
            set: { isOn in
                if isOn {
                    selectedTier = tier
                }
            }
        )
    }
}

#Preview("Choosing model") {
    MLXModelSetupSheet(
        selectedTier: .constant(.fast),
        isDownloading: false,
        downloadProgress: nil,
        downloadError: nil,
        onDownload: {},
        onCancel: {}
    )
}

#Preview("Downloading") {
    MLXModelSetupSheet(
        selectedTier: .constant(.fast),
        isDownloading: true,
        downloadProgress: MLXModelDownloadProgress(
            status: "Downloading MLX model files...",
            fraction: 0.42
        ),
        downloadError: nil,
        onDownload: {},
        onCancel: {}
    )
}
