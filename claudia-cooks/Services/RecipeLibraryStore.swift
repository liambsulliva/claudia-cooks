//
//  RecipeLibraryStore.swift
//  claudia-cooks
//

import Foundation
import Observation

@MainActor
@Observable
final class RecipeLibraryStore {
    private(set) var recipes: [SavedRecipe] = []
    var errorMessage: String?

    @ObservationIgnored private let fileManager: FileManager
    @ObservationIgnored private let libraryURL: URL
    @ObservationIgnored private let manifestURL: URL
    @ObservationIgnored private var pdfCache: [UUID: Data] = [:]

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        self.libraryURL = appSupportURL.appendingPathComponent("RecipeLibrary", isDirectory: true)
        self.manifestURL = libraryURL.appendingPathComponent("manifest.json")

        load()
    }

    var libraryFolderURL: URL {
        libraryURL
    }

    func recipe(for sessionID: UUID) -> SavedRecipe? {
        recipes.first { $0.id == sessionID }
    }

    func ensureBlankSession(sessionID: UUID, framework: RecipeFramework) {
        guard !recipes.contains(where: { $0.id == sessionID }) else {
            return
        }

        let now = Date()
        recipes.insert(
            SavedRecipe(
                id: sessionID,
                title: "Blank Page",
                framework: framework,
                createdAt: now,
                updatedAt: now,
                fileName: "",
                isBlank: true
            ),
            at: 0
        )

        do {
            try ensureLibraryDirectory()
            try persistManifest()
            errorMessage = nil
        } catch {
            errorMessage = "Recipe library could not save this file."
        }
    }

    func upsert(sessionID: UUID, title: String, framework: RecipeFramework, pdfData: Data) {
        do {
            try ensureLibraryDirectory()

            let now = Date()
            let fileName = "\(sessionID.uuidString).pdf"
            let fileURL = libraryURL.appendingPathComponent(fileName, isDirectory: false)
            try pdfData.write(to: fileURL, options: .atomic)

            if let existingIndex = recipes.firstIndex(where: { $0.id == sessionID }) {
                recipes[existingIndex].title = title
                recipes[existingIndex].framework = framework
                recipes[existingIndex].updatedAt = now
                recipes[existingIndex].fileName = fileName
                recipes[existingIndex].isBlank = false
            } else {
                recipes.append(
                    SavedRecipe(
                        id: sessionID,
                        title: title,
                        framework: framework,
                        createdAt: now,
                        updatedAt: now,
                        fileName: fileName,
                        isBlank: false
                    )
                )
            }

            recipes.sort { $0.updatedAt > $1.updatedAt }
            pdfCache[sessionID] = pdfData
            try persistManifest()
            errorMessage = nil
        } catch {
            errorMessage = "Recipe library could not save this PDF."
        }
    }

    func fileURL(for recipe: SavedRecipe) -> URL? {
        guard !recipe.isBlank, !recipe.fileName.isEmpty else {
            return nil
        }

        return libraryURL.appendingPathComponent(recipe.fileName, isDirectory: false)
    }

    func delete(recipe: SavedRecipe) {
        do {
            if let fileURL = fileURL(for: recipe), fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }

            pdfCache.removeValue(forKey: recipe.id)
            recipes.removeAll { $0.id == recipe.id }
            try persistManifest()
            errorMessage = nil
        } catch {
            errorMessage = "Recipe library could not delete this file."
        }
    }

    func pdfData(for recipe: SavedRecipe) -> Data? {
        guard !recipe.isBlank else {
            return nil
        }

        if let cachedData = pdfCache[recipe.id] {
            return cachedData
        }

        let fileURL = libraryURL.appendingPathComponent(recipe.fileName, isDirectory: false)
        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }

        pdfCache[recipe.id] = data
        return data
    }

    private func load() {
        do {
            try ensureLibraryDirectory()

            guard fileManager.fileExists(atPath: manifestURL.path) else {
                recipes = []
                return
            }

            let data = try Data(contentsOf: manifestURL)
            recipes = try JSONDecoder().decode([SavedRecipe].self, from: data)
                .sorted { $0.updatedAt > $1.updatedAt }
            errorMessage = nil
        } catch {
            recipes = []
            errorMessage = "Recipe library could not be loaded."
        }
    }

    private func persistManifest() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(recipes)
        try data.write(to: manifestURL, options: .atomic)
    }

    private func ensureLibraryDirectory() throws {
        try fileManager.createDirectory(at: libraryURL, withIntermediateDirectories: true)
    }
}
