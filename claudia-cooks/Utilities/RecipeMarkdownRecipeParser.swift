//
//  RecipeMarkdownRecipeParser.swift
//  claudia-cooks
//

import Foundation

enum RecipeMarkdownRecipeParser {
    static func parse(_ markdown: String, framework: RecipeFramework) -> GeneratedRecipe? {
        let lines = RecipeMarkdownFrontmatter.renderableBody(markdown).components(separatedBy: .newlines)
        var title = ""
        var summaryLines: [String] = []
        var sections: [RecipeSection: [String]] = [:]
        var activeSection: RecipeSection?
        var foundFrameworkLabel = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                continue
            }

            if isFrameworkLabel(trimmed, framework: framework) {
                foundFrameworkLabel = true
                continue
            }

            if let headingTitle = h1Title(from: trimmed) {
                title = headingTitle
                activeSection = nil
                continue
            }

            if trimmed.hasPrefix("# ") {
                title = cleanText(String(trimmed.dropFirst(2)))
                activeSection = nil
                continue
            }

            if let section = RecipeSection(markdownHeading: trimmed) {
                activeSection = section
                sections[section, default: []] = []
                continue
            }

            if let activeSection {
                sections[activeSection, default: []].append(trimmed)
            } else if !title.isEmpty || foundFrameworkLabel {
                summaryLines.append(trimmed)
            }
        }

        let ingredients = parseUnorderedList(sections[.ingredients] ?? [])
        let steps = parseOrderedList(sections[.steps] ?? [])
        let tips = parseUnorderedList(sections[.tips] ?? [])
        let summary = summaryLines
            .map(cleanText)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        let recipe = GeneratedRecipe(
            title: title.isEmpty ? "Untitled Recipe" : title,
            summary: summary,
            ingredients: ingredients,
            steps: steps,
            tips: tips
        )

        return recipe.hasMinimumRecipeContent ? recipe : nil
    }

    private static func isFrameworkLabel(_ line: String, framework: RecipeFramework) -> Bool {
        if line.localizedCaseInsensitiveContains("framework-label") {
            return true
        }

        return line == framework.title.uppercased()
    }

    private static func h1Title(from line: String) -> String? {
        let pattern = #"<h1\b[^>]*>(.*?)</h1>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let range = Range(match.range(at: 1), in: line) else {
            return nil
        }

        return cleanText(String(line[range]))
    }

    private static func parseUnorderedList(_ lines: [String]) -> [String] {
        lines.compactMap { line in
            if line.hasPrefix("- ") {
                return cleanText(String(line.dropFirst(2)))
            }

            return cleanText(line)
        }
        .filter { !$0.isEmpty && !isPlaceholderLine($0) }
    }

    private static func parseOrderedList(_ lines: [String]) -> [String] {
        let pattern = #"^\d+\.\s+(.*)$"#
        let regex = try? NSRegularExpression(pattern: pattern)

        return lines.compactMap { line in
            if let regex,
               let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
               let range = Range(match.range(at: 1), in: line) {
                return cleanText(String(line[range]))
            }

            return cleanText(line)
        }
        .filter { !$0.isEmpty && !isPlaceholderLine($0) }
    }

    private static func cleanText(_ text: String) -> String {
        stripHTMLTags(text)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: #"\\([\\`*_{}\[\]()#+\-.!])"#, with: "$1", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func stripHTMLTags(_ text: String) -> String {
        text.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
    }

    private static func isPlaceholderLine(_ text: String) -> Bool {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == "no ingredients generated yet."
            || normalized == "no steps generated yet."
            || normalized == "no tips generated yet."
    }
}

private enum RecipeSection: String {
    case ingredients
    case steps
    case tips

    init?(markdownHeading: String) {
        let normalized = markdownHeading
            .replacingOccurrences(of: "#", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        switch normalized {
        case "ingredients":
            self = .ingredients
        case "steps", "instructions", "method":
            self = .steps
        case "tips":
            self = .tips
        default:
            return nil
        }
    }
}
