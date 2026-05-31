//
//  MLXClient.swift
//  claudia-cooks
//

import Foundation
import HuggingFace
import MLXLLM
import MLXLMCommon

struct MLXClient: Sendable {
    private let configuration: MLXConfiguration
    private let systemLoad: MLXSystemLoad
    private let modelCache: MLXModelCache

    init(
        configuration: MLXConfiguration = .shared,
        systemLoad: MLXSystemLoad = .current(),
        modelCache: MLXModelCache = .shared
    ) {
        self.configuration = configuration
        self.systemLoad = systemLoad
        self.modelCache = modelCache
    }

    var preferredTier: MLXModelTier? {
        MLXModelPreferenceStore.preferredTier
    }

    var activeModel: String {
        configuration.resolvedModel(for: systemLoad, preferredTier: preferredTier)
    }

    var isFastestModel: Bool {
        MLXModelTier.tier(forModelName: activeModel) == .fastest
    }

    static func recommendedTier(for load: MLXSystemLoad = .current()) -> MLXModelTier {
        if let preferredTier = MLXModelPreferenceStore.preferredTier {
            return preferredTier
        }

        return load.shouldUseLowMemoryMode ? .fastest : .fast
    }

    func availability() async -> MLXAvailability {
        if await resolvedGenerationModel() != nil {
            return .ready
        }

        return .modelNotDownloaded(missingModel: activeModel)
    }

    func downloadModel(
        _ modelName: String,
        progressHandler: (@Sendable (MLXModelDownloadProgress) -> Void)? = nil
    ) async throws {
        _ = try await modelCache.container(
            modelName: modelName,
            configuration: configuration,
            progressHandler: progressHandler
        )
    }

    func generateRecipe(
        framework: RecipeFramework,
        selections: RecipeSelections,
        onPartialResponse: (@Sendable (String) -> Void)? = nil
    ) async throws -> GeneratedRecipe {
        guard let modelName = await resolvedGenerationModel() else {
            throw MLXClientError.modelNotFound(activeModel)
        }

        let container = try await modelCache.container(
            modelName: modelName,
            configuration: configuration,
            progressHandler: nil
        )

        let session = ChatSession(
            container,
            instructions: systemPrompt(for: framework),
            generateParameters: GenerateParameters(
                maxTokens: 700,
                temperature: 0.1,
                topP: 0.9,
                repetitionPenalty: 1.05
            ),
            additionalContext: ["enable_thinking": false]
        )

        var response = ""
        for try await chunk in session.streamResponse(
            to: userPrompt(framework: framework, selections: selections)
        ) {
            response += chunk
            onPartialResponse?(response)
        }

        if let recipe = GeneratedRecipe.decodePartialAssistantResponse(response),
           recipe.hasMinimumRecipeContent {
            return recipe
        }

        throw MLXClientError.invalidRecipePayload
    }

    func categorizeIngredients(_ ingredientNames: [String]) async throws -> [String: IngredientCategory] {
        let uniqueNames = Array(
            Set(
                ingredientNames
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            )
        ).sorted()

        guard !uniqueNames.isEmpty else {
            return [:]
        }

        guard let modelName = await resolvedGenerationModel() else {
            throw MLXClientError.modelNotFound(activeModel)
        }

        let container = try await modelCache.container(
            modelName: modelName,
            configuration: configuration,
            progressHandler: nil
        )

        let session = ChatSession(
            container,
            instructions: ingredientCategorySystemPrompt,
            generateParameters: GenerateParameters(
                maxTokens: 320,
                temperature: 0,
                topP: 0.9,
                repetitionPenalty: 1.02
            ),
            additionalContext: ["enable_thinking": false]
        )

        let list = uniqueNames
            .map { "- \(sanitizePromptText($0))" }
            .joined(separator: "\n")

        var response = ""
        for try await chunk in session.streamResponse(
            to: sanitizePromptText(
                """
                Classify each ingredient below.

                \(list)

                Return one JSON object. Use each ingredient string exactly as the key.
                """
            )
        ) {
            response += chunk
        }

        guard let categories = Self.decodeIngredientCategories(from: response, ingredientNames: uniqueNames) else {
            throw MLXClientError.invalidCategoryPayload
        }

        return categories
    }

    private var ingredientCategorySystemPrompt: String {
        """
        You classify cooking ingredients for a recipe graph.
        Assign each ingredient to exactly one category key: protein, carbs, veg, cheese, aromatics, sauces.
        Reply with a single JSON object only. No markdown, no code fences, no commentary.
        Example: {"chicken breasts":"protein","olive oil":"sauces","basil":"aromatics"}
        """
    }

    private static func decodeIngredientCategories(
        from text: String,
        ingredientNames: [String]
    ) -> [String: IngredientCategory]? {
        guard let data = extractJSONObject(from: text)?.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        var categories: [String: IngredientCategory] = [:]

        for name in ingredientNames {
            let rawValue = stringValue(from: object[name])
                ?? object.first(where: { IngredientLineParser.normalizedName(for: $0.key) == IngredientLineParser.normalizedName(for: name) })
                    .flatMap { stringValue(from: $0.value) }

            guard let rawValue, let category = IngredientCategory(rawValue: rawValue.lowercased()) else {
                continue
            }

            categories[name] = category
        }

        return categories.isEmpty ? nil : categories
    }

    private static func extractJSONObject(from text: String) -> String? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let start = normalized.firstIndex(of: "{"),
           let end = normalized.lastIndex(of: "}") {
            return String(normalized[start...end])
        }
        return nil
    }

    private static func stringValue(from value: Any?) -> String? {
        switch value {
        case let string as String:
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        default:
            return nil
        }
    }

    private func resolvedGenerationModel() async -> String? {
        if await isModelAvailable(activeModel) {
            return activeModel
        }

        let alternate = alternateModelName(for: activeModel)
        if await isModelAvailable(alternate) {
            return alternate
        }

        return nil
    }

    private func alternateModelName(for modelName: String) -> String {
        if modelName == configuration.lowMemoryModel {
            configuration.defaultModel
        } else {
            configuration.lowMemoryModel
        }
    }

    private func isModelAvailable(_ modelName: String) async -> Bool {
        do {
            let repoID = try configuration.repoID(for: modelName)
            _ = try await HubClient.default.downloadSnapshot(
                of: repoID,
                revision: "main",
                matching: configuration.downloadPatterns,
                localFilesOnly: true,
                maxConcurrentDownloads: 1
            )
            return true
        } catch {
            return false
        }
    }

    private func sanitizePromptText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "<", with: "(")
            .replacingOccurrences(of: ">", with: ")")
            .replacingOccurrences(of: "&", with: "and")
    }

    private func systemPrompt(for framework: RecipeFramework) -> String {
        """
        You are a practical cooking assistant for home cooks.
        Generate concise \(framework.title.lowercased()) recipes from the user's selections.
        Use only the selected ingredients plus common pantry staples such as salt, pepper, oil, water, and vinegar.
        Keep steps clear, safe, and realistic. Do not invent unavailable specialty ingredients.
        Reply with a single JSON object only. No markdown, no code fences, no commentary, no thinking tags.
        Required keys: title, summary, ingredients, steps, tips.
        ingredients, steps, and tips must be JSON arrays of strings.
        Example shape:
        {"title":"Garlic Herb Chicken","summary":"A quick skillet dinner.","ingredients":["2 chicken breasts","2 cloves garlic"],"steps":["Season the chicken.","Cook until done."],"tips":["Rest before slicing."]}
        """
    }

    private func userPrompt(framework: RecipeFramework, selections: RecipeSelections) -> String {
        let ingredientLines = selections.promptLines(for: framework.applicableCategories)
            .joined(separator: "\n")
        let customPrompt = sanitizePromptText(selections.normalizedCustomPrompt)

        var sections = ["Framework: \(sanitizePromptText(framework.title))"]

        if !customPrompt.isEmpty {
            sections.append("User request:\n\(customPrompt)")
        }

        if !ingredientLines.isEmpty {
            sections.append(sanitizePromptText(ingredientLines))
        }

        let ingredientInstruction = ingredientLines.isEmpty
            ? ""
            : "\nUse only the selected ingredients, plus common pantry staples such as salt, pepper, oil, water, and vinegar."

        let customInstruction = customPrompt.isEmpty
            ? ""
            : "\nHonor the user's request while keeping the recipe practical for home cooks."

        return sanitizePromptText(
            """
            \(sections.joined(separator: "\n\n"))

            Generate a concise home-cook recipe.\(ingredientInstruction)\(customInstruction)
            Return one JSON object with keys title, summary, ingredients, steps, and tips.
            Start with { and end with }. Do not wrap the JSON in markdown.
            """
        )
    }
}

enum MLXAvailability: Sendable, Equatable {
    case ready
    case modelNotDownloaded(missingModel: String)
}

enum MLXClientError: LocalizedError {
    case invalidModelIdentifier(String)
    case modelNotFound(String)
    case invalidRecipePayload
    case invalidCategoryPayload

    var errorDescription: String? {
        switch self {
        case .invalidModelIdentifier(let model):
            "MLX model identifier is invalid: \(model)"
        case .modelNotFound(let model):
            "\(model) is not downloaded yet. Choose a model size to download the MLX model files."
        case .invalidRecipePayload:
            "The recipe JSON from MLX could not be decoded. Try generating again."
        case .invalidCategoryPayload:
            "MLX could not classify one or more ingredients. Try again after the model finishes loading."
        }
    }
}
