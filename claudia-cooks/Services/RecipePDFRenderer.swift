//
//  RecipePDFRenderer.swift
//  claudia-cooks
//

import AppKit
import PDFKit

enum RecipePDFRenderer {
    static func render(
        recipe: GeneratedRecipe,
        framework: RecipeFramework,
        selections: RecipeSelections
    ) -> Data {
        renderDocument(framework: framework, selections: selections) { writer in
            writer.title(recipe.title, color: framework.nsAccentColor)
            writer.paragraph(recipe.summary)
            writer.section("Selected Ingredients")
            writer.bullets(selectionLines(framework: framework, selections: selections))
            writer.section("Ingredients")
            writer.bullets(recipe.ingredients)
            writer.section("Steps")
            writer.numbered(recipe.steps)
            writer.section("Tips")
            writer.bullets(recipe.tips)
        }
    }

    static func renderSelectionPreview(
        framework: RecipeFramework,
        selections: RecipeSelections,
        message: String? = nil
    ) -> Data {
        renderDocument(framework: framework, selections: selections) { writer in
            writer.title("\(framework.title) Builder", color: framework.nsAccentColor)

            if let message {
                writer.paragraph(message)
            }

            if !selections.normalizedCustomPrompt.isEmpty {
                writer.section("Your Prompt")
                writer.paragraph(selections.normalizedCustomPrompt)
            }

            if selections.isEmpty {
                writer.section("Start Building")
                writer.paragraph("Add a prompt above, pick ingredients, or both to generate a recipe.")
            } else {
                writer.section("Selected Ingredients")
                writer.bullets(selectionLines(framework: framework, selections: selections))
                writer.section("Preview")
                writer.paragraph("Your selected ingredients will appear here immediately. When the selected MLX model is downloaded, this pane updates with a generated recipe after each change.")
            }
        }
    }

    private static func renderDocument(
        framework: RecipeFramework,
        selections: RecipeSelections,
        content: (PDFPageWriter) -> Void
    ) -> Data {
        let document = PDFDocument()
        let writer = PDFPageWriter(document: document)
        writer.header(framework: framework)
        content(writer)
        writer.finishPage()
        return document.dataRepresentation() ?? Data()
    }

    private static func selectionLines(
        framework: RecipeFramework,
        selections: RecipeSelections
    ) -> [String] {
        framework.applicableCategories.compactMap { category in
            let items = selections.selectedItems(for: category)

            guard !items.isEmpty else {
                return nil
            }

            return "\(category.title): \(items.joined(separator: ", "))"
        }
    }
}
