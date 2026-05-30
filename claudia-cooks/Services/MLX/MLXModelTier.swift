//
//  MLXModelTier.swift
//  claudia-cooks
//

import Foundation

enum MLXModelTier: String, CaseIterable, Codable, Identifiable, Sendable {
    case fast
    case fastest

    var id: String { rawValue }

    var checkboxLabel: String {
        switch self {
        case .fast:
            "1.7B parameters (default, fast)"
        case .fastest:
            "0.6B parameters (fastest)"
        }
    }

    var checklistDetail: String {
        switch self {
        case .fast:
            "Best balance of speed and recipe quality; recommended for most Macs."
        case .fastest:
            "Smallest download and lowest latency; recommended for quicker outputs."
        }
    }

    var modelName: String {
        switch self {
        case .fast:
            MLXConfiguration.shared.defaultModel
        case .fastest:
            MLXConfiguration.shared.lowMemoryModel
        }
    }

    static func tier(forModelName modelName: String) -> MLXModelTier? {
        allCases.first { $0.modelName == modelName }
    }
}
