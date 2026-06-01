//
//  RecipeEditToolCall.swift
//  claudia-cooks
//

import Foundation

struct RecipeEditPatchResult: Equatable, Sendable {
    var recipe: GeneratedRecipe
    var changes: [RecipeEditAppliedChange]
}

struct RecipeEditAppliedChange: Equatable, Sendable {
    var id = UUID()
    var section: RecipeEditSection
    var index: Int?
    var before: String?
    var after: String?
}

enum RecipeEditSection: String, Sendable {
    case title
    case summary
    case ingredients
    case steps
    case tips
}

struct RecipeEditToolCall: Decodable, Equatable, Sendable {
    var name: String
    var arguments: RecipeEditToolArguments

    private enum CodingKeys: String, CodingKey {
        case name
        case tool
        case function
        case arguments
    }

    private struct FunctionPayload: Decodable {
        var name: String?
        var arguments: RecipeEditToolArguments?

        private enum CodingKeys: String, CodingKey {
            case name
            case arguments
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decodeIfPresent(String.self, forKey: .name)

            if let decodedArguments = try? container.decodeIfPresent(RecipeEditToolArguments.self, forKey: .arguments) {
                arguments = decodedArguments
            } else if let argumentsString = try? container.decodeIfPresent(String.self, forKey: .arguments) {
                arguments = RecipeEditToolCall.decodeArguments(from: argumentsString)
            } else {
                arguments = nil
            }
        }
    }

    init(name: String, arguments: RecipeEditToolArguments) {
        self.name = name
        self.arguments = arguments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let functionPayload = try? container.decodeIfPresent(FunctionPayload.self, forKey: .function)
        name = Self.decodeString(from: container, forKey: .name)
            ?? Self.decodeString(from: container, forKey: .tool)
            ?? Self.decodeString(from: container, forKey: .function)
            ?? functionPayload?.name
            ?? ""

        if let decodedArguments = try? container.decodeIfPresent(RecipeEditToolArguments.self, forKey: .arguments) {
            arguments = decodedArguments
        } else if let argumentsString = try? container.decodeIfPresent(String.self, forKey: .arguments),
                  let decodedArguments = Self.decodeArguments(from: argumentsString) {
            arguments = decodedArguments
        } else if let functionArguments = functionPayload?.arguments {
            arguments = functionArguments
        } else {
            arguments = try RecipeEditToolArguments(from: decoder)
        }
    }

    private static func decodeString(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> String? {
        guard let value = try? container.decodeIfPresent(String.self, forKey: key) else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func decodeArguments(from json: String) -> RecipeEditToolArguments? {
        guard let data = json.data(using: .utf8) else {
            return nil
        }

        return try? JSONDecoder().decode(RecipeEditToolArguments.self, from: data)
    }

    static func decodeAssistantResponse(_ text: String) -> [RecipeEditToolCall]? {
        let decoder = JSONDecoder()

        for candidate in jsonCandidates(from: text) {
            guard let data = candidate.data(using: .utf8) else {
                continue
            }

            if let envelope = try? decoder.decode(RecipeEditToolCallEnvelope.self, from: data),
               !envelope.toolCalls.isEmpty {
                return envelope.toolCalls
            }

            if let calls = try? decoder.decode([RecipeEditToolCall].self, from: data),
               !calls.isEmpty {
                return calls
            }

            if let call = try? decoder.decode(RecipeEditToolCall.self, from: data),
               !call.name.isEmpty {
                return [call]
            }
        }

        return nil
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

        let normalized = stripThinking(from: text)
            .replacingOccurrences(of: "\u{FEFF}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        append(normalized)

        if let fenced = extractMarkdownJSON(from: normalized) {
            append(fenced)
        }

        candidates.append(contentsOf: extractBalancedJSON(from: normalized, opening: "{", closing: "}"))
        candidates.append(contentsOf: extractBalancedJSON(from: normalized, opening: "[", closing: "]"))

        return candidates
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

    private static func extractBalancedJSON(
        from text: String,
        opening: Character,
        closing: Character
    ) -> [String] {
        var results: [String] = []
        var searchStart = text.startIndex

        while searchStart < text.endIndex,
              let start = text[searchStart...].firstIndex(of: opening) {
            guard let object = extractBalancedJSON(from: text, startingAt: start, opening: opening, closing: closing) else {
                results.append(String(text[start...]))
                break
            }

            results.append(object)
            searchStart = text.index(after: start)
        }

        return results
    }

    private static func extractBalancedJSON(
        from text: String,
        startingAt start: String.Index,
        opening: Character,
        closing: Character
    ) -> String? {
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
            case opening:
                depth += 1
            case closing:
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

    private static func stripThinking(from text: String) -> String {
        var result = text
        let tagPairs = [
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

struct RecipeEditToolArguments: Decodable, Equatable, Sendable {
    var index: Int?
    var from: String?
    var to: String?
    var text: String?
    var value: String?
    var title: String?
    var summary: String?

    private enum CodingKeys: String, CodingKey {
        case index
        case position
        case from
        case oldText
        case old_text
        case before
        case to
        case newText
        case new_text
        case after
        case text
        case value
        case title
        case summary
    }

    init(
        index: Int? = nil,
        from: String? = nil,
        to: String? = nil,
        text: String? = nil,
        value: String? = nil,
        title: String? = nil,
        summary: String? = nil
    ) {
        self.index = index
        self.from = from
        self.to = to
        self.text = text
        self.value = value
        self.title = title
        self.summary = summary
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        index = Self.decodeInt(from: container, keys: [.index, .position])
        from = Self.decodeString(from: container, keys: [.from, .oldText, .old_text, .before])
        to = Self.decodeString(from: container, keys: [.to, .newText, .new_text, .after])
        text = Self.decodeString(from: container, keys: [.text])
        value = Self.decodeString(from: container, keys: [.value])
        title = Self.decodeString(from: container, keys: [.title])
        summary = Self.decodeString(from: container, keys: [.summary])
    }

    private static func decodeInt(
        from container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> Int? {
        for key in keys {
            if let value = try? container.decode(Int.self, forKey: key) {
                return value
            }

            if let string = try? container.decode(String.self, forKey: key),
               let value = Int(string.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return value
            }
        }

        return nil
    }

    private static func decodeString(
        from container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> String? {
        for key in keys {
            if let value = try? container.decode(String.self, forKey: key) {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
        }

        return nil
    }
}

private struct RecipeEditToolCallEnvelope: Decodable {
    var toolCalls: [RecipeEditToolCall]

    private enum CodingKeys: String, CodingKey {
        case toolCalls
        case tool_calls
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        toolCalls = try container.decodeIfPresent([RecipeEditToolCall].self, forKey: .tool_calls)
            ?? container.decodeIfPresent([RecipeEditToolCall].self, forKey: .toolCalls)
            ?? []
    }
}

enum RecipeEditToolCallApplier {
    static func apply(
        _ change: RecipeEditAppliedChange,
        to recipe: GeneratedRecipe
    ) -> GeneratedRecipe {
        var editedRecipe = recipe

        switch change.section {
        case .title:
            if let after = change.after {
                editedRecipe.title = after
            }
        case .summary:
            if let after = change.after {
                editedRecipe.summary = after
            }
        case .ingredients:
            apply(change, to: &editedRecipe.ingredients)
            editedRecipe.syncEntriesFromIngredients()
        case .steps:
            apply(change, to: &editedRecipe.steps)
        case .tips:
            apply(change, to: &editedRecipe.tips)
        }

        return editedRecipe
    }

    static func apply(
        _ toolCalls: [RecipeEditToolCall],
        to recipe: GeneratedRecipe
    ) -> RecipeEditPatchResult {
        var editedRecipe = recipe
        var changes: [RecipeEditAppliedChange] = []

        for call in toolCalls {
            let name = normalizedToolName(call.name)

            switch name {
            case "settitle", "updatetitle", "replacetitle":
                applyTextEdit(
                    section: .title,
                    currentValue: &editedRecipe.title,
                    arguments: call.arguments,
                    preferredValue: call.arguments.title,
                    changes: &changes
                )

            case "setsummary", "updatesummary", "replacesummary":
                applyTextEdit(
                    section: .summary,
                    currentValue: &editedRecipe.summary,
                    arguments: call.arguments,
                    preferredValue: call.arguments.summary,
                    changes: &changes
                )

            case "addingredient":
                applyAdd(section: .ingredients, to: &editedRecipe.ingredients, arguments: call.arguments, changes: &changes)

            case "replaceingredient", "updateingredient":
                applyReplace(section: .ingredients, to: &editedRecipe.ingredients, arguments: call.arguments, changes: &changes)

            case "removeingredient", "deleteingredient":
                applyRemove(section: .ingredients, from: &editedRecipe.ingredients, arguments: call.arguments, changes: &changes)

            case "addstep":
                applyAdd(section: .steps, to: &editedRecipe.steps, arguments: call.arguments, changes: &changes)

            case "replacestep", "updatestep":
                applyReplace(section: .steps, to: &editedRecipe.steps, arguments: call.arguments, changes: &changes)

            case "removestep", "deletestep":
                applyRemove(section: .steps, from: &editedRecipe.steps, arguments: call.arguments, changes: &changes)

            case "addtip":
                applyAdd(section: .tips, to: &editedRecipe.tips, arguments: call.arguments, changes: &changes)

            case "replacetip", "updatetip":
                applyReplace(section: .tips, to: &editedRecipe.tips, arguments: call.arguments, changes: &changes)

            case "removetip", "deletetip":
                applyRemove(section: .tips, from: &editedRecipe.tips, arguments: call.arguments, changes: &changes)

            default:
                continue
            }
        }

        if changes.contains(where: { $0.section == .ingredients }) {
            editedRecipe.syncEntriesFromIngredients()
        }

        return RecipeEditPatchResult(recipe: editedRecipe, changes: changes)
    }

    private static func apply(
        _ change: RecipeEditAppliedChange,
        to values: inout [String]
    ) {
        switch (change.before, change.after) {
        case (.none, .some(let newValue)):
            values.insert(newValue, at: min(max(change.index ?? values.count, 0), values.count))
        case (.some(let oldValue), .some(let newValue)):
            guard let index = resolvedChangeIndex(index: change.index, matching: oldValue, in: values) else {
                return
            }
            values[index] = newValue
        case (.some(let oldValue), .none):
            guard let index = resolvedChangeIndex(index: change.index, matching: oldValue, in: values) else {
                return
            }
            values.remove(at: index)
        case (.none, .none):
            return
        }
    }

    private static func applyTextEdit(
        section: RecipeEditSection,
        currentValue: inout String,
        arguments: RecipeEditToolArguments,
        preferredValue: String?,
        changes: inout [RecipeEditAppliedChange]
    ) {
        guard let newValue = preferredValue ?? newText(from: arguments),
              newValue != currentValue else {
            return
        }

        let oldValue = currentValue
        currentValue = newValue
        changes.append(
            RecipeEditAppliedChange(
                section: section,
                index: nil,
                before: oldValue,
                after: newValue
            )
        )
    }

    private static func applyAdd(
        section: RecipeEditSection,
        to values: inout [String],
        arguments: RecipeEditToolArguments,
        changes: inout [RecipeEditAppliedChange]
    ) {
        guard let newValue = newText(from: arguments) else {
            return
        }

        let insertIndex = insertionIndex(arguments.index, count: values.count)
        values.insert(newValue, at: insertIndex)
        changes.append(
            RecipeEditAppliedChange(
                section: section,
                index: insertIndex,
                before: nil,
                after: newValue
            )
        )
    }

    private static func applyReplace(
        section: RecipeEditSection,
        to values: inout [String],
        arguments: RecipeEditToolArguments,
        changes: inout [RecipeEditAppliedChange]
    ) {
        guard let newValue = newText(from: arguments),
              let replaceIndex = resolvedIndex(arguments: arguments, in: values),
              values[replaceIndex] != newValue else {
            return
        }

        let oldValue = values[replaceIndex]
        values[replaceIndex] = newValue
        changes.append(
            RecipeEditAppliedChange(
                section: section,
                index: replaceIndex,
                before: oldValue,
                after: newValue
            )
        )
    }

    private static func applyRemove(
        section: RecipeEditSection,
        from values: inout [String],
        arguments: RecipeEditToolArguments,
        changes: inout [RecipeEditAppliedChange]
    ) {
        guard let removeIndex = resolvedIndex(arguments: arguments, in: values) else {
            return
        }

        let oldValue = values.remove(at: removeIndex)
        changes.append(
            RecipeEditAppliedChange(
                section: section,
                index: removeIndex,
                before: oldValue,
                after: nil
            )
        )
    }

    private static func resolvedIndex(
        arguments: RecipeEditToolArguments,
        in values: [String]
    ) -> Int? {
        resolvedIndex(index: arguments.index, matching: arguments.from, in: values)
    }

    private static func resolvedIndex(
        index: Int?,
        matching oldValue: String?,
        in values: [String]
    ) -> Int? {
        if let oldValue,
           let matchingIndex = values.firstIndex(where: { normalizedRecipeText($0) == normalizedRecipeText(oldValue) }) {
            return matchingIndex
        }

        if let index {
            let zeroBasedIndex = index > 0 ? index - 1 : index
            if values.indices.contains(zeroBasedIndex) {
                return zeroBasedIndex
            }
        }

        return nil
    }

    private static func resolvedChangeIndex(
        index: Int?,
        matching oldValue: String,
        in values: [String]
    ) -> Int? {
        if let matchingIndex = values.firstIndex(where: { normalizedRecipeText($0) == normalizedRecipeText(oldValue) }) {
            return matchingIndex
        }

        if let index, values.indices.contains(index) {
            return index
        }

        return nil
    }

    private static func insertionIndex(_ index: Int?, count: Int) -> Int {
        guard let index else {
            return count
        }

        let zeroBasedIndex = index > 0 ? index - 1 : index
        return min(max(zeroBasedIndex, 0), count)
    }

    private static func newText(from arguments: RecipeEditToolArguments) -> String? {
        arguments.to ?? arguments.text ?? arguments.value
    }

    private static func normalizedToolName(_ name: String) -> String {
        let loweredName = name.lowercased()
        let functionName = loweredName
            .split(separator: ".")
            .last
            .map(String.init)
            ?? loweredName

        return functionName.filter { $0.isLetter || $0.isNumber }
    }

    private static func normalizedRecipeText(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .lowercased()
    }
}
