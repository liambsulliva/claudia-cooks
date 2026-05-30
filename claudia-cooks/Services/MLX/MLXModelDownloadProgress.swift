//
//  MLXModelDownloadProgress.swift
//  claudia-cooks
//

import Foundation

struct MLXModelDownloadProgress: Sendable, Equatable {
    let status: String
    let fraction: Double?

    static let starting = MLXModelDownloadProgress(
        status: "Preparing MLX model download...",
        fraction: nil
    )

    static let loading = MLXModelDownloadProgress(
        status: "Loading MLX model into memory...",
        fraction: nil
    )

    static func downloading(_ progress: Progress) -> MLXModelDownloadProgress {
        let fraction: Double?
        if progress.totalUnitCount > 0 {
            fraction = min(1, max(0, Double(progress.completedUnitCount) / Double(progress.totalUnitCount)))
        } else {
            fraction = nil
        }

        let status = progress.isFinished
            ? "Verifying MLX model files..."
            : "Downloading MLX model files..."

        return MLXModelDownloadProgress(
            status: status,
            fraction: fraction
        )
    }

    var percentComplete: Int? {
        guard let fraction else {
            return nil
        }

        return min(100, max(0, Int((fraction * 100).rounded())))
    }

    var detailLine: String {
        var parts: [String] = [status]

        if let percentComplete {
            parts.append("\(percentComplete)%")
        }

        return parts.joined(separator: " - ")
    }
}
