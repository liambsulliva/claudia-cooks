//
//  GeneratedRecipe+Decoding.swift
//  claudia-cooks
//

import Foundation

extension GeneratedRecipe {
    var hasMinimumIngredientsContent: Bool {
        hasRealTitle && !ingredients.isEmpty
    }

    var hasMinimumInstructionsContent: Bool {
        !steps.isEmpty
    }

    var hasMinimumRecipeContent: Bool {
        hasMinimumIngredientsContent && hasMinimumInstructionsContent
    }

    private var hasRealTitle: Bool {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return !normalizedTitle.isEmpty
            && normalizedTitle != "generating recipe…"
            && normalizedTitle != "untitled recipe"
    }

    static func decodePartialAssistantResponse(_ text: String) -> GeneratedRecipe? {
        decodeBestEffort(from: text, allowPartial: true)
    }

    private static func decodeBestEffort(from text: String, allowPartial: Bool) -> GeneratedRecipe? {
        for candidate in jsonCandidates(from: text) {
            if let recipe = try? decode(from: candidate) {
                return recipe
            }

            if let recipe = decodeLenient(from: candidate) {
                return recipe
            }

            if let repaired = repairTruncatedJSON(candidate),
               let recipe = decodeLenient(from: repaired) {
                return recipe
            }
        }

        let trimmed = normalizeModelText(text)
        guard trimmed.contains("{") else {
            return nil
        }

        let title = extractJSONStringField("title", from: trimmed)
        let summary = extractJSONStringField("summary", from: trimmed)
        let ingredients = extractJSONStringArrayField("ingredients", from: trimmed)
        let steps = extractJSONStringArrayField("steps", from: trimmed)
        let tips = extractJSONStringArrayField("tips", from: trimmed)

        guard title != nil || summary != nil || !ingredients.isEmpty || !steps.isEmpty || !tips.isEmpty else {
            return nil
        }

        let recipe = GeneratedRecipe(
            title: title ?? "Generating recipe…",
            summary: summary ?? "",
            ingredients: ingredients,
            steps: steps,
            tips: tips
        )

        if allowPartial {
            return recipe
        }

        return recipe.hasMinimumRecipeContent ? recipe : nil
    }

    private static func jsonCandidates(from text: String) -> [String] {
        var candidates: [String] = []
        var seen = Set<String>()

        func append(_ candidate: String) {
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed).inserted else {
                return
            }
            candidates.append(trimmed)
        }

        let normalized = normalizeModelText(text)
        append(normalized)

        if let fenced = extractMarkdownJSON(from: normalized) {
            append(fenced)
        }

        for object in extractJSONObjectStrings(from: normalized) {
            append(object)
        }

        return candidates
    }

    private static func normalizeModelText(_ text: String) -> String {
        var result = stripThinking(from: text)
            .replacingOccurrences(of: "\u{FEFF}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let firstBrace = result.firstIndex(of: "{"),
           firstBrace > result.startIndex {
            let prefix = result[..<firstBrace]
            if !prefix.contains("\"") || prefix.contains("think") || prefix.contains("assistant") {
                result = String(result[firstBrace...])
            }
        }

        return result
    }

    private static func extractMarkdownJSON(from text: String) -> String? {
        guard text.contains("```") else {
            return nil
        }

        var working = text
        if working.hasPrefix("```json") {
            working = String(working.dropFirst("```json".count))
        } else if working.hasPrefix("```") {
            working = String(working.dropFirst(3))
        }

        if let fenceEnd = working.range(of: "```") {
            working = String(working[..<fenceEnd.lowerBound])
        }

        return working.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractJSONObjectStrings(from text: String) -> [String] {
        var results: [String] = []
        var searchStart = text.startIndex

        while searchStart < text.endIndex,
              let start = text[searchStart...].firstIndex(of: "{") {
            if let object = extractBalancedJSONObject(from: text, startingAt: start) {
                results.append(object)
                searchStart = text.index(after: start)
            } else {
                results.append(String(text[start...]))
                break
            }
        }

        return results
    }

    private static func extractBalancedJSONObject(from text: String, startingAt start: String.Index) -> String? {
        var depth = 0
        var inString = false
        var isEscaped = false

        for index in text[start...].indices {
            let character = text[index]

            if inString {
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == "\"" {
                    inString = false
                }
                continue
            }

            switch character {
            case "\"":
                inString = true
            case "{":
                depth += 1
            case "}":
                depth -= 1
                if depth == 0 {
                    return String(text[start...index])
                }
            default:
                break
            }
        }

        return nil
    }

    private static func repairTruncatedJSON(_ json: String) -> String? {
        var repaired = json.trimmingCharacters(in: .whitespacesAndNewlines)
        guard repaired.contains("{") else {
            return nil
        }

        while repaired.last == "," || repaired.last == "\n" || repaired.last == " " {
            repaired.removeLast()
        }

        var braceDepth = 0
        var bracketDepth = 0
        var inString = false
        var isEscaped = false

        for character in repaired {
            if inString {
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == "\"" {
                    inString = false
                }
                continue
            }

            switch character {
            case "\"":
                inString = true
            case "{":
                braceDepth += 1
            case "}":
                braceDepth -= 1
            case "[":
                bracketDepth += 1
            case "]":
                bracketDepth -= 1
            default:
                break
            }
        }

        if inString {
            repaired.append("\"")
        }

        if bracketDepth > 0 {
            repaired.append(contentsOf: Array(repeating: "]", count: bracketDepth))
        }

        if braceDepth > 0 {
            repaired.append(contentsOf: Array(repeating: "}", count: braceDepth))
        }

        return repaired
    }

    private static func decodeLenient(from json: String) -> GeneratedRecipe? {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let title = stringValue(from: object["title"])
        let summary = stringValue(from: object["summary"])
        let ingredients = stringArray(from: object["ingredients"])
        let steps = stringArray(from: object["steps"])
        let tips = stringArray(from: object["tips"])

        guard title != nil || summary != nil || !ingredients.isEmpty || !steps.isEmpty || !tips.isEmpty else {
            return nil
        }

        return GeneratedRecipe(
            title: title ?? "Untitled Recipe",
            summary: summary ?? "",
            ingredients: ingredients,
            steps: steps,
            tips: tips
        )
    }

    private static func stringValue(from value: Any?) -> String? {
        switch value {
        case let string as String:
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        case let number as NSNumber:
            return number.stringValue
        default:
            return nil
        }
    }

    private static func stringArray(from value: Any?) -> [String] {
        switch value {
        case let strings as [String]:
            return strings
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        case let strings as [Any]:
            return strings.compactMap { stringValue(from: $0) }
        case let string as String:
            return string
                .split(whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        default:
            return []
        }
    }

    private static func extractJSONStringField(_ field: String, from text: String) -> String? {
        let pattern = #""\#(field)"\s*:\s*"((?:\\.|[^"\\])*)""#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let valueRange = Range(match.range(at: 1), in: text) else {
            return nil
        }

        return decodeJSONString(String(text[valueRange]))
    }

    private static func extractJSONStringArrayField(_ field: String, from text: String) -> [String] {
        let openPattern = #""\#(field)"\s*:\s*\[(.*)"#
        guard let openRegex = try? NSRegularExpression(pattern: openPattern, options: [.dotMatchesLineSeparators]),
              let match = openRegex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let arrayRange = Range(match.range(at: 1), in: text) else {
            return []
        }

        let arrayBody = String(text[arrayRange])
        let itemPattern = #""((?:\\.|[^"\\])*)""#
        guard let itemRegex = try? NSRegularExpression(pattern: itemPattern) else {
            return []
        }

        return itemRegex.matches(in: arrayBody, range: NSRange(arrayBody.startIndex..., in: arrayBody)).compactMap { match in
            guard let valueRange = Range(match.range(at: 1), in: arrayBody) else {
                return nil
            }

            return decodeJSONString(String(arrayBody[valueRange]))
        }
    }

    private static func decodeJSONString(_ value: String) -> String {
        let data = Data("\"\(value)\"".utf8)
        if let decoded = try? JSONDecoder().decode(String.self, from: data) {
            return decoded
        }

        return value
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }

    private static func decode(from json: String) throws -> GeneratedRecipe {
        let data = Data(json.utf8)
        return try JSONDecoder().decode(GeneratedRecipe.self, from: data)
    }

    private static func stripThinking(from text: String) -> String {
        var result = text

        let tagPairs: [(String, String)] = [
            ("<\("think")>", "</\("think")>"),
            ("<\("redacted_thinking")>", "</\("redacted_thinking")>"),
            ("<thinking>", "</thinking>"),
            ("<reasoning>", "</reasoning>")
        ]

        for (openTag, closeTag) in tagPairs {
            while let start = result.range(of: openTag, options: .caseInsensitive),
                  let end = result.range(
                    of: closeTag,
                    options: .caseInsensitive,
                    range: start.upperBound..<result.endIndex
                  ) {
                result.removeSubrange(start.lowerBound..<end.upperBound)
            }
        }

        return result
    }
}
