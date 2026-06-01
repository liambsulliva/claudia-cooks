//
//  RecipeLibraryFileNaming.swift
//  claudia-cooks
//

import Foundation

enum RecipeLibraryFileNaming {
    private static let maxBaseNameLength = 120

    /// Produces a unique `.md` file name for a recipe title within the library folder.
    static func fileName(
        forTitle title: String,
        occupiedFileNames: Set<String>
    ) -> String {
        let baseName = sanitizedBaseName(from: title)
        var candidate = "\(baseName).md"
        var duplicateIndex = 2

        while occupiedFileNames.contains(candidate) {
            candidate = "\(baseName) \(duplicateIndex).md"
            duplicateIndex += 1
        }

        return candidate
    }

    static func sanitizedBaseName(from title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = trimmed.isEmpty ? "Untitled Recipe" : trimmed

        var sanitized = ""
        sanitized.reserveCapacity(fallback.count)

        for scalar in fallback.unicodeScalars {
            if CharacterSet.controlCharacters.contains(scalar) {
                continue
            }

            switch scalar.value {
            case 0x2F, 0x3A: // / :
                sanitized.append(" ")
            default:
                sanitized.unicodeScalars.append(scalar)
            }
        }

        let collapsed = sanitized
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))

        let resolved = collapsed.isEmpty ? "Untitled Recipe" : collapsed
        if resolved.count <= maxBaseNameLength {
            return resolved
        }

        return String(resolved.prefix(maxBaseNameLength)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isUUIDBasedFileName(_ fileName: String) -> Bool {
        guard fileName.hasSuffix(".md") else {
            return false
        }

        let stem = String(fileName.dropLast(3))
        return UUID(uuidString: stem) != nil
    }

    static func preferredFileName(
        for recipe: SavedRecipe,
        occupiedFileNames: Set<String>
    ) -> String {
        fileName(forTitle: recipe.title, occupiedFileNames: occupiedFileNames)
    }
}
