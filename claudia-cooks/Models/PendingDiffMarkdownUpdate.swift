//
//  PendingDiffMarkdownUpdate.swift
//  claudia-cooks
//

import Foundation

struct PendingDiffMarkdownUpdate: Codable, Equatable, Sendable {
    var markdown: String
    var additions: [PendingDiffAdditionEdit]
}

struct PendingDiffAdditionEdit: Codable, Equatable, Sendable {
    var id: String
    var text: String
}

struct PendingDiffDisplayFingerprint: Equatable, Sendable {
    var changeIDs: [UUID]

    init(pendingDiff: RecipeEditPendingDiff) {
        changeIDs = pendingDiff.changes.map(\.id)
    }
}
