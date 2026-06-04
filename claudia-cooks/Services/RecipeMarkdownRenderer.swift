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
                bullets(recipe.markdownIngredientLines, emptyMessage: "No ingredients generated yet."),
                section("Steps"),
                numbered(recipe.steps, emptyMessage: "No steps generated yet."),
                section("Tips"),
                bullets(recipe.tips, emptyMessage: "No tips generated yet."),
                section("Nutrition"),
                bullets(recipe.macros?.markdownLines ?? [], emptyMessage: "No nutrition generated yet.")
            ]
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
            return ""
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
