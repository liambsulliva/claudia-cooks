//
//  RecipeMarkdownDiffRenderer.swift
//  claudia-cooks
//

import Foundation

enum RecipeMarkdownDiffRenderer {
    static func html(
        pendingDiff: RecipeEditPendingDiff,
        framework: RecipeFramework,
        isInteractive: Bool = false
    ) -> String {
        let recipe = pendingDiff.originalRecipe
        let changes = pendingDiff.changes

        let body = [
            frameworkHeader(framework),
            scalarBlockHTML(
                section: .title,
                fallback: recipe.title,
                changes: changes,
                tag: "h1",
                className: "recipe-title",
                style: "color: \(framework.htmlAccentHex)"
            ),
            scalarBlockHTML(
                section: .summary,
                fallback: recipe.summary,
                changes: changes,
                tag: "p",
                className: "recipe-summary",
                style: nil
            ),
            sectionHeading("Ingredients"),
            listBlockHTML(section: .ingredients, items: recipe.ingredients, changes: changes),
            sectionHeading("Steps"),
            listBlockHTML(section: .steps, items: recipe.steps, changes: changes),
            sectionHeading("Tips"),
            listBlockHTML(section: .tips, items: recipe.tips, changes: changes)
        ]
        .filter { !$0.isEmpty }
        .joined(separator: "\n")

        return RecipeMarkdownDocument.diffHTML(
            body: body,
            framework: framework,
            isInteractive: isInteractive
        )
    }

    private static func frameworkHeader(_ framework: RecipeFramework) -> String {
        "<p class=\"framework-label\">\(MarkdownToHTML.escapeHTML(framework.title.uppercased()))</p>"
    }

    private static func sectionHeading(_ title: String) -> String {
        "<h2>\(MarkdownToHTML.escapeHTML(title))</h2>"
    }

    private static func scalarBlockHTML(
        section: RecipeEditSection,
        fallback: String,
        changes: [RecipeEditAppliedChange],
        tag: String,
        className: String,
        style: String?
    ) -> String {
        let rows = RecipeDiffDisplayBuilder.scalarRows(
            section: section,
            fallback: fallback,
            changes: changes
        )

        return renderGroupedRows(
            rows,
            lineTag: tag,
            groupWrapperTag: "div",
            groupWrapperClass: "diff-change-block",
            className: className,
            style: style
        )
    }

    private static func listBlockHTML(
        section: RecipeEditSection,
        items: [String],
        changes: [RecipeEditAppliedChange]
    ) -> String {
        let rows = RecipeDiffDisplayBuilder.listRows(
            section: section,
            items: items,
            changes: changes
        )

        guard !rows.isEmpty else {
            return "<p class=\"recipe-empty\">No content.</p>"
        }

        let itemsHTML = renderGroupedRows(
            rows,
            lineTag: "div",
            groupWrapperTag: "li",
            groupWrapperClass: nil,
            className: nil,
            style: nil
        )

        return "<ul class=\"recipe-diff-list\">\n\(itemsHTML)\n</ul>"
    }

    private struct RecipeDiffRowGroup {
        var changeID: UUID?
        var rows: [RecipeDiffDisplayRow]
    }

    private static func groupRows(_ rows: [RecipeDiffDisplayRow]) -> [RecipeDiffRowGroup] {
        var groups: [RecipeDiffRowGroup] = []

        for row in rows {
            if row.kind != .unchanged, let changeID = row.changeID {
                if let lastIndex = groups.indices.last,
                   groups[lastIndex].changeID == changeID {
                    groups[lastIndex].rows.append(row)
                } else {
                    groups.append(RecipeDiffRowGroup(changeID: changeID, rows: [row]))
                }
            } else {
                groups.append(RecipeDiffRowGroup(changeID: nil, rows: [row]))
            }
        }

        return groups
    }

    private static func renderGroupedRows(
        _ rows: [RecipeDiffDisplayRow],
        lineTag: String,
        groupWrapperTag: String,
        groupWrapperClass: String?,
        className: String?,
        style: String?
    ) -> String {
        groupRows(rows).map { group in
            if let changeID = group.changeID {
                diffChangeGroupHTML(
                    changeID: changeID,
                    rows: group.rows,
                    lineTag: lineTag,
                    wrapperTag: groupWrapperTag,
                    wrapperClass: groupWrapperClass,
                    className: className,
                    style: style
                )
            } else {
                group.rows.map { row in
                    unchangedLineHTML(
                        row,
                        tag: listUnchangedTag(for: lineTag),
                        className: className,
                        style: style
                    )
                }
                .joined(separator: "\n")
            }
        }
        .joined(separator: "\n")
    }

    private static func listUnchangedTag(for lineTag: String) -> String {
        lineTag == "div" ? "li" : lineTag
    }

    private static func diffChangeGroupHTML(
        changeID: UUID,
        rows: [RecipeDiffDisplayRow],
        lineTag: String,
        wrapperTag: String,
        wrapperClass: String?,
        className: String?,
        style: String?
    ) -> String {
        let wrapperClasses = ["diff-change-group", wrapperClass]
            .compactMap { $0 }
            .joined(separator: " ")

        let lines = rows.enumerated().map { index, row in
            diffLineInnerHTML(
                row,
                tag: lineTag,
                className: className,
                style: style,
                reviewAnchor: index == rows.count - 1
            )
        }
        .joined(separator: "\n")

        return """
        <\(wrapperTag) class="\(wrapperClasses)" data-change-id="\(changeID.uuidString)">
        \(lines)
        </\(wrapperTag)>
        """
    }

    private static func diffReviewPopoverHTML() -> String {
        """
        <div class="diff-review-popover" contenteditable="false" role="group" aria-label="Review change">
        <button type="button" class="diff-review-y" contenteditable="false" aria-label="Accept change" title="Accept" onclick="return window.claudiaReviewChange('accept', this, event)">Y</button>
        <button type="button" class="diff-review-n" contenteditable="false" aria-label="Reject change" title="Reject" onclick="return window.claudiaReviewChange('deny', this, event)">N</button>
        </div>
        """
    }

    private static func unchangedLineHTML(
        _ row: RecipeDiffDisplayRow,
        tag: String,
        className: String?,
        style: String?
    ) -> String {
        let escapedText = MarkdownToHTML.escapeHTML(row.text)
        let classes = [className, "diff-unchanged"]
            .compactMap { $0 }
            .joined(separator: " ")
        let classAttribute = classes.isEmpty ? "" : " class=\"\(classes)\""
        let styleAttribute = style.map { " style=\"\($0)\"" } ?? ""
        return "<\(tag)\(classAttribute)\(styleAttribute)>\(escapedText)</\(tag)>"
    }

    private static func diffLineInnerHTML(
        _ row: RecipeDiffDisplayRow,
        tag: String,
        className: String?,
        style: String?,
        reviewAnchor: Bool = false
    ) -> String {
        let escapedText = MarkdownToHTML.escapeHTML(row.text)
        let classes = [
            "diff-line",
            reviewAnchor ? "diff-review-anchor" : nil,
            className,
            diffClassName(for: row.kind)
        ]
        .compactMap { $0 }
        .joined(separator: " ")

        let prefix = row.kind == .addition ? "+" : "−"
        let editableAttribute = row.kind == .removal ? " contenteditable=\"false\"" : ""
        let styleAttribute = style.map { " style=\"\($0)\"" } ?? ""
        let popover = reviewAnchor ? diffReviewPopoverHTML() : ""

        return """
        <\(tag) class="\(classes)"\(styleAttribute)\(editableAttribute)>\
        <span class="diff-prefix">\(prefix)</span>\
        <span class="diff-text">\(escapedText)</span>\
        \(popover)\
        </\(tag)>
        """
    }

    private static func diffClassName(for kind: RecipeDiffDisplayRow.Kind) -> String? {
        switch kind {
        case .unchanged: nil
        case .addition: "diff-addition"
        case .removal: "diff-removal"
        }
    }
}
