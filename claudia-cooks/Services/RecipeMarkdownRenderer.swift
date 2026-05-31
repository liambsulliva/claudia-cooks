//
//  RecipeMarkdownRenderer.swift
//  claudia-cooks
//

import Foundation

enum RecipeMarkdownRenderer {
    static func render(
        recipe: GeneratedRecipe,
        framework: RecipeFramework
    ) -> String {
        renderDocument(framework: framework) {
            [
                htmlTitle(recipe.title, framework: framework),
                paragraph(recipe.summary),
                section("Ingredients"),
                bullets(recipe.ingredients, emptyMessage: "No ingredients generated yet."),
                section("Steps"),
                numbered(recipe.steps, emptyMessage: "No steps generated yet."),
                section("Tips"),
                bullets(recipe.tips, emptyMessage: "No tips generated yet.")
            ]
        }
    }

    static func renderSelectionPreview(
        framework: RecipeFramework,
        selections: RecipeSelections,
        message: String? = nil
    ) -> String {
        renderDocument(framework: framework) {
            var blocks = [
                htmlTitle("\(framework.title) Builder", framework: framework)
            ]

            if let message {
                blocks.append(paragraph(message))
            }

            if !selections.normalizedCustomPrompt.isEmpty {
                blocks.append(section("Your Prompt"))
                blocks.append(paragraph(selections.normalizedCustomPrompt))
            }

            if selections.isEmpty {
                blocks.append(section("Start Building"))
                blocks.append(paragraph("Add a prompt above, pick ingredients, or both to generate a recipe."))
            } else {
                blocks.append(section("Preview"))
                blocks.append(
                    paragraph(
                        "When the selected MLX model is downloaded, this pane updates with a generated recipe after each change."
                    )
                )
            }

            return blocks
        }
    }

    private static func renderDocument(
        framework: RecipeFramework,
        content: () -> [String]
    ) -> String {
        ([frameworkHeader(framework)] + content())
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    private static func frameworkHeader(_ framework: RecipeFramework) -> String {
        "<p class=\"framework-label\">\(MarkdownToHTML.escapeHTML(framework.title.uppercased()))</p>"
    }

    private static func htmlTitle(_ text: String, framework: RecipeFramework) -> String {
        let escaped = MarkdownToHTML.escapeHTML(text)
        return "<h1 class=\"recipe-title\" style=\"color: \(framework.htmlAccentHex)\">\(escaped)</h1>"
    }

    private static func section(_ text: String) -> String {
        "## \(MarkdownToHTML.escapeMarkdown(text))"
    }

    private static func paragraph(_ text: String) -> String {
        MarkdownToHTML.escapeMarkdown(text)
    }

    private static func bullets(_ items: [String], emptyMessage: String? = nil) -> String {
        guard !items.isEmpty else {
            if let emptyMessage {
                return paragraph(emptyMessage)
            }
            return paragraph("No selections yet.")
        }

        return items
            .map { "- \(MarkdownToHTML.escapeMarkdown($0))" }
            .joined(separator: "\n")
    }

    private static func numbered(_ items: [String], emptyMessage: String) -> String {
        guard !items.isEmpty else {
            return paragraph(emptyMessage)
        }

        return items.enumerated()
            .map { index, item in
                "\(index + 1). \(MarkdownToHTML.escapeMarkdown(item))"
            }
            .joined(separator: "\n")
    }
}
