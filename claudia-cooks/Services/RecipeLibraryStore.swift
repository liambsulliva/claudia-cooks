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
        let recipe = SavedRecipe(
            id: sessionID,
            title: "Blank Page",
            framework: framework,
            createdAt: now,
            updatedAt: now,
            fileName: "",
            isBlank: true,
            selections: selections.stored
        )

        do {
            try ensureLibraryDirectory()
            let fileName = try writeRecipeDocument(recipe, body: "")
            var persistedRecipe = recipe
            persistedRecipe.fileName = fileName
            recipes.insert(persistedRecipe, at: 0)
            markdownCache[sessionID] = ""
            errorMessage = nil
        } catch {
            errorMessage = "Recipe library could not save this file."
        }
    }

    func updateRecipeMarkdown(
        _ markdown: String,
        for recipeID: UUID,
        ingredientEntries: [GeneratedIngredient]? = nil
    ) {
        guard let index = recipes.firstIndex(where: { $0.id == recipeID }) else {
            return
        }

        do {
            try ensureLibraryDirectory()
            let body = RecipeMarkdownFrontmatter.renderableBody(markdown)
            syncTitleFromMarkdown(body, at: index)

            recipes[index].isBlank = false
            recipes[index].updatedAt = Date()

            if let ingredientEntries {
                let sanitized = GeneratedIngredient.sanitized(ingredientEntries)
                if !sanitized.isEmpty {
                    recipes[index].ingredientEntries = sanitized
                }
            }

            let fileName = try writeRecipeDocument(recipes[index], body: body)
            recipes[index].fileName = fileName
            markdownCache[recipeID] = body
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

            recipes[index].title = "Blank Page"
            recipes[index].isBlank = true
            recipes[index].updatedAt = Date()

            let fileName = try writeRecipeDocument(recipes[index], body: "")
            recipes[index].fileName = fileName
            markdownCache[recipeID] = ""
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
        recipes[index].updatedAt = Date()

        do {
            try ensureLibraryDirectory()
            let body = try recipeBody(for: recipes[index])
            let fileName = try writeRecipeDocument(recipes[index], body: body)
            recipes[index].fileName = fileName
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
        selections: RecipeSelections,
        ingredientEntries: [GeneratedIngredient] = []
    ) {
        do {
            try ensureLibraryDirectory()

            let now = Date()
            let existingIndex = recipes.firstIndex(where: { $0.id == sessionID })
            let previousFileName = existingIndex.map { recipes[$0].fileName } ?? ""
            let body = RecipeMarkdownFrontmatter.renderableBody(recipeMarkdown)

            if let existingIndex {
                recipes[existingIndex].title = title
                recipes[existingIndex].framework = framework
                recipes[existingIndex].updatedAt = now
                recipes[existingIndex].isBlank = false
                recipes[existingIndex].selections = selections.stored
                if !ingredientEntries.isEmpty {
                    recipes[existingIndex].ingredientEntries = ingredientEntries
                }
            } else {
                recipes.append(
                    SavedRecipe(
                        id: sessionID,
                        title: title,
                        framework: framework,
                        createdAt: now,
                        updatedAt: now,
                        fileName: previousFileName,
                        isBlank: false,
                        selections: selections.stored,
                        ingredientEntries: ingredientEntries
                    )
                )
            }

            guard let index = recipes.firstIndex(where: { $0.id == sessionID }) else {
                return
            }

            let fileName = try writeRecipeDocument(recipes[index], body: body)
            recipes[index].fileName = fileName
            recipes.sort { $0.createdAt > $1.createdAt }
            markdownCache[sessionID] = body
            errorMessage = nil
        } catch {
            errorMessage = "Recipe library could not save this recipe."
        }
    }

    func fileURL(for recipe: SavedRecipe) -> URL? {
        guard !recipe.fileName.isEmpty else {
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
            return cachedMarkdown.isEmpty ? nil : cachedMarkdown
        }

        guard let body = try? recipeBody(for: recipe), !body.isEmpty else {
            return nil
        }

        markdownCache[recipe.id] = body
        return body
    }

    /// Reloads recipe metadata and markdown caches after external file changes.
    func syncFromDisk() {
        guard !isSyncingFromDisk else {
            return
        }

        isSyncingFromDisk = true
        defer { isSyncingFromDisk = false }

        let previousRecipeIDs = Set(recipes.map(\.id))
        reloadRecipesFromDisk()

        let removedRecipeIDs = previousRecipeIDs.subtracting(recipes.map(\.id))
        for recipeID in removedRecipeIDs {
            markdownCache.removeValue(forKey: recipeID)
        }

        for recipe in recipes where !recipe.isBlank {
            markdownCache.removeValue(forKey: recipe.id)
        }
    }

    private func load() {
        do {
            try ensureLibraryDirectory()
            try migrateManifestToFrontmatterIfNeeded()
            reloadRecipesFromDisk()
            try migrateLegacyFileNamesIfNeeded()
        } catch {
            recipes = []
            errorMessage = "Recipe library could not be loaded."
        }
    }

    private func reloadRecipesFromDisk() {
        guard let fileNames = try? fileManager.contentsOfDirectory(atPath: libraryURL.path) else {
            recipes = []
            markdownCache.removeAll()
            errorMessage = "Recipe library could not be loaded."
            return
        }

        var loadedRecipes: [SavedRecipe] = []

        for fileName in fileNames where fileName.hasSuffix(".md") {
            let fileURL = libraryURL.appendingPathComponent(fileName, isDirectory: false)
            guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else {
                continue
            }

            if let recipe = savedRecipe(fromFileName: fileName, contents: contents, fileURL: fileURL) {
                loadedRecipes.append(recipe)
            }
        }

        let sortedRecipes = loadedRecipes.sorted { $0.createdAt > $1.createdAt }
        if sortedRecipes != recipes {
            recipes = sortedRecipes
        }

        errorMessage = nil
    }

    private func savedRecipe(
        fromFileName fileName: String,
        contents: String,
        fileURL: URL
    ) -> SavedRecipe? {
        let (metadata, body) = RecipeMarkdownFrontmatter.split(contents)

        if let metadata {
            var recipe = metadata.savedRecipe(fileName: fileName)
            if !metadata.isBlank,
               let parsedRecipe = RecipeMarkdownRecipeParser.parse(body, framework: recipe.framework) {
                recipe.title = parsedRecipe.title
            }
            return recipe
        }

        return legacySavedRecipe(
            fromFileName: fileName,
            body: RecipeMarkdownFrontmatter.renderableBody(contents),
            fileURL: fileURL
        )
    }

    private func legacySavedRecipe(
        fromFileName fileName: String,
        body: String,
        fileURL: URL
    ) -> SavedRecipe? {
        let fileDates = (try? fileURL.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])) ?? nil
        let createdAt = fileDates?.creationDate ?? Date()
        let updatedAt = fileDates?.contentModificationDate ?? createdAt

        let stem = String(fileName.dropLast(3))
        let recipeID = UUID(uuidString: stem) ?? UUID()
        let framework: RecipeFramework = .bowls
        let parsedTitle = RecipeMarkdownRecipeParser.parse(body, framework: framework)?.title
        let title = parsedTitle ?? stem

        return SavedRecipe(
            id: recipeID,
            title: title,
            framework: framework,
            createdAt: createdAt,
            updatedAt: updatedAt,
            fileName: fileName,
            isBlank: body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            selections: StoredRecipeSelections()
        )
    }

    private func migrateManifestToFrontmatterIfNeeded() throws {
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            return
        }

        let data = try Data(contentsOf: manifestURL)
        let manifestRecipes = try JSONDecoder().decode([SavedRecipe].self, from: data)

        for recipe in manifestRecipes {
            let body: String
            if !recipe.fileName.isEmpty {
                let fileURL = libraryURL.appendingPathComponent(recipe.fileName, isDirectory: false)
                if fileManager.fileExists(atPath: fileURL.path),
                   let contents = try? String(contentsOf: fileURL, encoding: .utf8) {
                    body = RecipeMarkdownFrontmatter.renderableBody(contents)
                } else {
                    body = ""
                }
            } else {
                body = ""
            }

            _ = try writeRecipeDocument(recipe, body: body)
        }

        for fileName in try fileManager.contentsOfDirectory(atPath: libraryURL.path) where fileName.hasSuffix(".md") {
            let recipeID = manifestRecipes.first(where: { $0.fileName == fileName })?.id
            if recipeID == nil, let contents = try? String(
                contentsOf: libraryURL.appendingPathComponent(fileName),
                encoding: .utf8
            ),
               RecipeMarkdownFrontmatter.split(contents).metadata == nil,
               let legacyRecipe = legacySavedRecipe(
                   fromFileName: fileName,
                   body: RecipeMarkdownFrontmatter.renderableBody(contents),
                   fileURL: libraryURL.appendingPathComponent(fileName)
               ) {
                _ = try writeRecipeDocument(legacyRecipe, body: RecipeMarkdownFrontmatter.renderableBody(contents))
            }
        }

        try fileManager.removeItem(at: manifestURL)
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

    private func ensureLibraryDirectory() throws {
        try fileManager.createDirectory(at: libraryURL, withIntermediateDirectories: true)
    }

    private func occupiedFileNames(excludingRecipeID: UUID? = nil) -> Set<String> {
        Set(
            recipes
                .filter { recipe in
                    recipe.id != excludingRecipeID && !recipe.fileName.isEmpty
                }
                .map(\.fileName)
        )
    }

    private func syncTitleFromMarkdown(_ markdown: String, at index: Int) {
        guard let parsedRecipe = RecipeMarkdownRecipeParser.parse(
            markdown,
            framework: recipes[index].framework
        ) else {
            return
        }

        recipes[index].title = parsedRecipe.title
    }

    @discardableResult
    private func writeRecipeDocument(_ recipe: SavedRecipe, body: String) throws -> String {
        let preferredFileName = RecipeLibraryFileNaming.fileName(
            forTitle: recipe.title,
            occupiedFileNames: occupiedFileNames(excludingRecipeID: recipe.id)
        )

        var fileName = recipe.fileName
        if fileName.isEmpty {
            fileName = preferredFileName
        } else if fileName != preferredFileName {
            try renameRecipeFileOnDisk(from: fileName, to: preferredFileName)
            fileName = preferredFileName
        }

        let fileURL = libraryURL.appendingPathComponent(fileName, isDirectory: false)
        let document = RecipeMarkdownFrontmatter.document(for: recipe, body: body)
        try document.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileName
    }

    private func recipeBody(for recipe: SavedRecipe) throws -> String {
        if let cachedBody = markdownCache[recipe.id] {
            return cachedBody
        }

        guard let fileURL = fileURL(for: recipe) else {
            return ""
        }

        let contents = try String(contentsOf: fileURL, encoding: .utf8)
        return RecipeMarkdownFrontmatter.renderableBody(contents)
    }

    private func renameRecipeFileOnDisk(from oldFileName: String, to newFileName: String) throws {
        guard oldFileName != newFileName else {
            return
        }

        let oldURL = libraryURL.appendingPathComponent(oldFileName, isDirectory: false)
        let newURL = libraryURL.appendingPathComponent(newFileName, isDirectory: false)

        guard fileManager.fileExists(atPath: oldURL.path) else {
            return
        }

        if fileManager.fileExists(atPath: newURL.path) {
            try fileManager.removeItem(at: newURL)
        }

        try fileManager.moveItem(at: oldURL, to: newURL)
    }

    private func migrateLegacyFileNamesIfNeeded() throws {
        var didMigrate = false

        for index in recipes.indices {
            let recipe = recipes[index]
            guard !recipe.fileName.isEmpty else {
                continue
            }

            let shouldMigrate = RecipeLibraryFileNaming.isUUIDBasedFileName(recipe.fileName)
                || recipe.fileName != RecipeLibraryFileNaming.preferredFileName(
                    for: recipe,
                    occupiedFileNames: occupiedFileNames(excludingRecipeID: recipe.id)
                )

            guard shouldMigrate else {
                continue
            }

            let newFileName = RecipeLibraryFileNaming.fileName(
                forTitle: recipe.title,
                occupiedFileNames: occupiedFileNames(excludingRecipeID: recipe.id)
            )

            if recipe.fileName != newFileName {
                try renameRecipeFileOnDisk(from: recipe.fileName, to: newFileName)
                recipes[index].fileName = newFileName
                if let body = try? recipeBody(for: recipes[index]) {
                    _ = try writeRecipeDocument(recipes[index], body: body)
                }
                didMigrate = true
            }
        }

        if didMigrate {
            reloadRecipesFromDisk()
        }
    }
}
