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
    @ObservationIgnored private var markdownCache: [UUID: String] = [:]
    @ObservationIgnored private var directoryWatcher: RecipeLibraryDirectoryWatcher?
    @ObservationIgnored private var syncDebounceTask: Task<Void, Never>?
    @ObservationIgnored private var isSyncingFromDisk = false

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        self.libraryURL = appSupportURL.appendingPathComponent("RecipeLibrary", isDirectory: true)
        self.manifestURL = libraryURL.appendingPathComponent("manifest.json")

        load()
        startWatchingLibraryDirectory()
    }

    deinit {
        syncDebounceTask?.cancel()
        directoryWatcher = nil
    }

    var libraryFolderURL: URL {
        libraryURL
    }

    func recipe(for sessionID: UUID) -> SavedRecipe? {
        recipes.first { $0.id == sessionID }
    }

    func ensureBlankSession(
        sessionID: UUID,
        framework: RecipeFramework,
        selections: RecipeSelections = RecipeSelections()
    ) {
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
                isBlank: true,
                selections: selections.stored
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

    func updateRecipeMarkdown(_ markdown: String, for recipeID: UUID) {
        guard let index = recipes.firstIndex(where: { $0.id == recipeID }) else {
            return
        }

        do {
            try ensureLibraryDirectory()

            let fileName = recipes[index].fileName.isEmpty
                ? "\(recipeID.uuidString).md"
                : recipes[index].fileName
            let fileURL = libraryURL.appendingPathComponent(fileName, isDirectory: false)
            try markdown.write(to: fileURL, atomically: true, encoding: .utf8)

            recipes[index].fileName = fileName
            recipes[index].isBlank = false
            recipes[index].updatedAt = Date()
            markdownCache[recipeID] = markdown
            try persistManifest()
            errorMessage = nil
        } catch {
            errorMessage = "Recipe library could not save this recipe."
        }
    }

    func clearRecipeDocument(for recipeID: UUID) {
        guard let index = recipes.firstIndex(where: { $0.id == recipeID }) else {
            return
        }

        do {
            try ensureLibraryDirectory()

            let recipe = recipes[index]
            if let fileURL = fileURL(for: recipe),
               fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }

            markdownCache.removeValue(forKey: recipeID)
            recipes[index].title = "Blank Page"
            recipes[index].fileName = ""
            recipes[index].isBlank = true
            recipes[index].updatedAt = Date()
            try persistManifest()
            errorMessage = nil
        } catch {
            errorMessage = "Recipe library could not clear this file."
        }
    }

    func updateSelections(_ selections: RecipeSelections, for recipeID: UUID) {
        guard let index = recipes.firstIndex(where: { $0.id == recipeID }) else {
            return
        }

        recipes[index].selections = selections.stored

        do {
            try persistManifest()
            errorMessage = nil
        } catch {
            errorMessage = "Recipe library could not save ingredient selections."
        }
    }

    func upsert(
        sessionID: UUID,
        title: String,
        framework: RecipeFramework,
        recipeMarkdown: String,
        selections: RecipeSelections
    ) {
        do {
            try ensureLibraryDirectory()

            let now = Date()
            let fileName = "\(sessionID.uuidString).md"
            let fileURL = libraryURL.appendingPathComponent(fileName, isDirectory: false)
            try recipeMarkdown.write(to: fileURL, atomically: true, encoding: .utf8)

            if let existingIndex = recipes.firstIndex(where: { $0.id == sessionID }) {
                recipes[existingIndex].title = title
                recipes[existingIndex].framework = framework
                recipes[existingIndex].updatedAt = now
                recipes[existingIndex].fileName = fileName
                recipes[existingIndex].isBlank = false
                recipes[existingIndex].selections = selections.stored
            } else {
                recipes.append(
                    SavedRecipe(
                        id: sessionID,
                        title: title,
                        framework: framework,
                        createdAt: now,
                        updatedAt: now,
                        fileName: fileName,
                        isBlank: false,
                        selections: selections.stored
                    )
                )
            }

            recipes.sort { $0.createdAt > $1.createdAt }
            markdownCache[sessionID] = recipeMarkdown
            try persistManifest()
            errorMessage = nil
        } catch {
            errorMessage = "Recipe library could not save this recipe."
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

            markdownCache.removeValue(forKey: recipe.id)
            recipes.removeAll { $0.id == recipe.id }
            try persistManifest()
            errorMessage = nil
        } catch {
            errorMessage = "Recipe library could not delete this file."
        }
    }

    func recipeMarkdown(for recipe: SavedRecipe) -> String? {
        guard !recipe.isBlank else {
            return nil
        }

        if let cachedMarkdown = markdownCache[recipe.id] {
            return cachedMarkdown
        }

        let fileURL = libraryURL.appendingPathComponent(recipe.fileName, isDirectory: false)
        guard let markdown = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return nil
        }

        markdownCache[recipe.id] = markdown
        return markdown
    }

    /// Reloads manifest metadata and markdown caches after external file changes.
    func syncFromDisk() {
        guard !isSyncingFromDisk else {
            return
        }

        isSyncingFromDisk = true
        defer { isSyncingFromDisk = false }

        let previousRecipeIDs = Set(recipes.map(\.id))
        reloadRecipesFromManifest()

        let removedRecipeIDs = previousRecipeIDs.subtracting(recipes.map(\.id))
        for recipeID in removedRecipeIDs {
            markdownCache.removeValue(forKey: recipeID)
        }

        for recipe in recipes where !recipe.isBlank && !recipe.fileName.isEmpty {
            markdownCache.removeValue(forKey: recipe.id)
        }
    }

    private func load() {
        do {
            try ensureLibraryDirectory()
            reloadRecipesFromManifest()
        } catch {
            recipes = []
            errorMessage = "Recipe library could not be loaded."
        }
    }

    private func reloadRecipesFromManifest() {
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            recipes = []
            markdownCache.removeAll()
            errorMessage = nil
            return
        }

        do {
            let data = try Data(contentsOf: manifestURL)
            let decodedRecipes = try JSONDecoder().decode([SavedRecipe].self, from: data)
                .sorted { $0.createdAt > $1.createdAt }

            if decodedRecipes != recipes {
                recipes = decodedRecipes
            }

            errorMessage = nil
        } catch {
            errorMessage = "Recipe library could not be loaded."
        }
    }

    private func startWatchingLibraryDirectory() {
        do {
            try ensureLibraryDirectory()
        } catch {
            return
        }

        directoryWatcher = RecipeLibraryDirectoryWatcher(libraryURL: libraryURL) { [weak self] in
            Task { @MainActor in
                self?.scheduleSyncFromDisk()
            }
        }
    }

    private func scheduleSyncFromDisk() {
        syncDebounceTask?.cancel()
        syncDebounceTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(300))
            } catch {
                return
            }

            self?.syncFromDisk()
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
