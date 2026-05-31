//
//  RecipeMarkdownRenderer.swift
//  claudia-cooks
//

import Foundation

enum RecipeMarkdownRenderer {
    static func render(
        recipe: GeneratedRecipe,
        framework: RecipeFramework,
        selections: RecipeSelections
    ) -> String {
        renderDocument(framework: framework) {
            [
                htmlTitle(recipe.title, framework: framework),
                paragraph(recipe.summary),
                section("Selected Ingredients"),
                badgeList(
                    selectionLines(framework: framework, selections: selections),
                    badgeID: RecipeBadgeID.selection
                ),
                section("Ingredients"),
                badgeList(
                    recipe.ingredients,
                    badgeID: RecipeBadgeID.ingredient,
                    emptyMessage: "No ingredients generated yet."
                ),
                section("Steps"),
                badgeList(
                    recipe.steps,
                    badgeID: RecipeBadgeID.step,
                    emptyMessage: "No steps generated yet."
                ),
                section("Tips"),
                badgeList(
                    recipe.tips,
                    badgeID: RecipeBadgeID.tip,
                    emptyMessage: "No tips generated yet."
                )
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
                blocks.append(section("Selected Ingredients"))
                blocks.append(
                    badgeList(
                        selectionLines(framework: framework, selections: selections),
                        badgeID: RecipeBadgeID.selection
                    )
                )
                blocks.append(section("Preview"))
                blocks.append(
                    paragraph(
                        "Your selected ingredients will appear here immediately. When the selected MLX model is downloaded, this pane updates with a generated recipe after each change."
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

    private static func badgeList(
        _ items: [String],
        badgeID: (Int) -> String,
        emptyMessage: String? = nil
    ) -> String {
        guard !items.isEmpty else {
            if let emptyMessage {
                return paragraph(emptyMessage)
            }
            return paragraph("No selections yet.")
        }

        let rows = items.enumerated()
            .map { index, item in
                badgeRow(id: badgeID(index), text: item)
            }
            .joined(separator: "\n")

        return "<ul class=\"badge-list\">\n\(rows)\n</ul>"
    }

    private static func badgeRow(id: String, text: String) -> String {
        let escapedID = MarkdownToHTML.escapeHTML(id)
        let escapedText = MarkdownToHTML.escapeHTML(text)
        return """
        <li class="badge-row" data-badge-row-id="\(escapedID)">
          <button type="button" class="recipe-badge" data-badge-id="\(escapedID)" aria-pressed="false">Save</button>
          <span class="badge-text">\(escapedText)</span>
        </li>
        """
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
