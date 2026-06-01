//
//  RecipeMarkdownFrontmatter.swift
//  claudia-cooks
//

import Foundation

enum RecipeMarkdownFrontmatter {
    struct Metadata: Codable, Equatable {
        var id: UUID
        var title: String
        var framework: RecipeFramework
        var createdAt: Date
        var updatedAt: Date
        var isBlank: Bool
        var selections: StoredRecipeSelections
        var ingredientEntries: [GeneratedIngredient]

        init(from recipe: SavedRecipe) {
            id = recipe.id
            title = recipe.title
            framework = recipe.framework
            createdAt = recipe.createdAt
            updatedAt = recipe.updatedAt
            isBlank = recipe.isBlank
            selections = recipe.selections
            ingredientEntries = recipe.ingredientEntries
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            title = try container.decode(String.self, forKey: .title)
            framework = try container.decode(RecipeFramework.self, forKey: .framework)
            createdAt = try container.decode(Date.self, forKey: .createdAt)
            updatedAt = try container.decode(Date.self, forKey: .updatedAt)
            isBlank = try container.decodeIfPresent(Bool.self, forKey: .isBlank) ?? false
            selections = try container.decodeIfPresent(StoredRecipeSelections.self, forKey: .selections) ?? StoredRecipeSelections()
            ingredientEntries = try container.decodeIfPresent([GeneratedIngredient].self, forKey: .ingredientEntries) ?? []
        }

        func savedRecipe(fileName: String) -> SavedRecipe {
            SavedRecipe(
                id: id,
                title: title,
                framework: framework,
                createdAt: createdAt,
                updatedAt: updatedAt,
                fileName: fileName,
                isBlank: isBlank,
                selections: selections,
                ingredientEntries: GeneratedIngredient.sanitized(ingredientEntries)
            )
        }
    }

    static func split(_ markdown: String) -> (metadata: Metadata?, body: String) {
        let lines = markdown.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        guard let first = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines),
              first == "---",
              let closingLineIndex = lines.dropFirst().firstIndex(where: {
                  $0.trimmingCharacters(in: .whitespacesAndNewlines) == "---"
              }) else {
            return (nil, markdown)
        }

        let jsonLines = lines[1..<closingLineIndex]
        let metadata = decodeMetadata(from: jsonLines.joined(separator: "\n"))
        let bodyLines = lines[(closingLineIndex + 1)...]
        let body = bodyLines.joined(separator: "\n")
        return (metadata, body)
    }

    static func renderableBody(_ markdown: String) -> String {
        split(markdown).body
    }

    static func document(metadata: Metadata, body: String) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let jsonData = try? encoder.encode(metadata),
              let json = String(data: jsonData, encoding: .utf8) else {
            return body
        }

        let trimmedBody = body.trimmingCharacters(in: .newlines)
        if trimmedBody.isEmpty {
            return "---\n\(json)\n---\n"
        }

        return "---\n\(json)\n---\n\n\(body)"
    }

    static func document(for recipe: SavedRecipe, body: String) -> String {
        document(metadata: Metadata(from: recipe), body: renderableBody(body))
    }

    private static func decodeMetadata(from json: String) -> Metadata? {
        let trimmed = json.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let data = trimmed.data(using: .utf8) else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Metadata.self, from: data)
    }
}
