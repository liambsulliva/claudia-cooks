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
        onPartialResponse: (@Sendable (GeneratedRecipe) -> Void)? = nil
    ) async throws -> GeneratedRecipe {
        guard let modelName = await resolvedGenerationModel() else {
            throw MLXClientError.modelNotFound(activeModel)
        }

        let container = try await modelCache.container(
            modelName: modelName,
            configuration: configuration,
            progressHandler: nil
        )

        var recipe = GeneratedRecipe(
            title: "Generating recipe…",
            summary: "",
            ingredients: [],
            steps: [],
            tips: []
        )

        let ingredientsResponse = try await streamChatResponse(
            container: container,
            instructions: ingredientsSystemPrompt(for: framework),
            userMessage: ingredientsUserPrompt(framework: framework, selections: selections),
            maxTokens: 420
        ) { partialText in
            guard let partial = GeneratedRecipe.decodePartialAssistantResponse(partialText) else {
                return
            }

            recipe.title = partial.title
            recipe.summary = partial.summary
            recipe.ingredients = partial.ingredients
            onPartialResponse?(recipe)
        }

        guard let ingredientsRecipe = GeneratedRecipe.decodePartialAssistantResponse(ingredientsResponse),
              ingredientsRecipe.hasMinimumIngredientsContent else {
            throw MLXClientError.invalidRecipePayload
        }

        recipe.title = ingredientsRecipe.title
        recipe.summary = ingredientsRecipe.summary
        recipe.ingredients = ingredientsRecipe.ingredients
        onPartialResponse?(recipe)

        let instructionsResponse = try await streamChatResponse(
            container: container,
            instructions: instructionsSystemPrompt(for: framework),
            userMessage: instructionsUserPrompt(
                framework: framework,
                selections: selections,
                ingredients: recipe.ingredients,
                title: recipe.title,
                summary: recipe.summary
            ),
            maxTokens: 520
        ) { partialText in
            guard let partial = GeneratedRecipe.decodePartialAssistantResponse(partialText) else {
                return
            }

            recipe.steps = partial.steps
            recipe.tips = partial.tips
            onPartialResponse?(recipe)
        }

        guard let instructionsRecipe = GeneratedRecipe.decodePartialAssistantResponse(instructionsResponse),
              instructionsRecipe.hasMinimumInstructionsContent else {
            throw MLXClientError.invalidRecipePayload
        }

        recipe.steps = instructionsRecipe.steps
        recipe.tips = instructionsRecipe.tips

        guard recipe.hasMinimumRecipeContent else {
            throw MLXClientError.invalidRecipePayload
        }

        onPartialResponse?(recipe)
        return recipe
    }

    private func streamChatResponse(
        container: ModelContainer,
        instructions: String,
        userMessage: String,
        maxTokens: Int,
        onPartialText: (@Sendable (String) -> Void)? = nil
    ) async throws -> String {
        let session = ChatSession(
            container,
            instructions: instructions,
            generateParameters: GenerateParameters(
                maxTokens: maxTokens,
                temperature: 0.1,
                topP: 0.9,
                repetitionPenalty: 1.05
            ),
            additionalContext: ["enable_thinking": false]
        )

        var response = ""
        for try await chunk in session.streamResponse(to: userMessage) {
            response += chunk
            onPartialText?(response)
        }

        return response
    }

    func categorizeIngredients(_ ingredientNames: [String]) async throws -> [String: IngredientCategory] {
        let uniqueNames = Array(
            Set(
                ingredientNames
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .filter { !RecipeMarkdownIngredientsParser.isLikelyStepContent($0) }
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
        Do not prepend the ingredients with adjectives like "chopped", "sliced", "diced", etc.
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

    private func ingredientsSystemPrompt(for framework: RecipeFramework) -> String {
        """
        You are a practical cooking assistant for home cooks.
        Generate the ingredient list for a concise \(framework.title.lowercased()) recipe from the user's selections.
        Use only the selected ingredients plus common pantry staples such as salt, pepper, oil, water, and vinegar.
        Do not invent unavailable specialty ingredients.
        Reply with a single JSON object only. No markdown, no code fences, no commentary, no thinking tags.
        Required keys: title, summary, ingredients.
        ingredients must be a JSON array of strings with quantities (for example "2 chicken breasts", "1 tbsp olive oil").
        Example shape:
        {"title":"Garlic Herb Chicken","summary":"A quick skillet dinner.","ingredients":["2 chicken breasts","2 cloves garlic","1 tbsp olive oil"]}
        """
    }

    private func instructionsSystemPrompt(for framework: RecipeFramework) -> String {
        """
        You are a practical cooking assistant for home cooks.
        Write clear, safe, realistic cooking instructions for a \(framework.title.lowercased()) recipe.
        Use the provided ingredient list exactly; do not add new ingredients beyond common pantry staples already listed.
        Reply with a single JSON object only. No markdown, no code fences, no commentary, no thinking tags.
        Required keys: steps, tips.
        steps and tips must be JSON arrays of strings.
        Example shape:
        {"steps":["Season the chicken.","Sear until golden, then finish in the oven."],"tips":["Rest before slicing."]}
        """
    }

    private func sharedPromptSections(
        framework: RecipeFramework,
        selections: RecipeSelections
    ) -> (sections: [String], ingredientLines: String, customPrompt: String) {
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

        return (sections, ingredientLines, customPrompt)
    }

    private func ingredientsUserPrompt(framework: RecipeFramework, selections: RecipeSelections) -> String {
        let context = sharedPromptSections(framework: framework, selections: selections)

        let ingredientInstruction = context.ingredientLines.isEmpty
            ? ""
            : "\nUse only the selected ingredients, plus common pantry staples such as salt, pepper, oil, water, and vinegar."

        let customInstruction = context.customPrompt.isEmpty
            ? ""
            : "\nHonor the user's request while keeping the recipe practical for home cooks."

        return sanitizePromptText(
            """
            \(context.sections.joined(separator: "\n\n"))

            Generate the recipe title, summary, and ingredient list.\(ingredientInstruction)\(customInstruction)
            Return one JSON object with keys title, summary, and ingredients only.
            Start with { and end with }. Do not wrap the JSON in markdown.
            """
        )
    }

    private func instructionsUserPrompt(
        framework: RecipeFramework,
        selections: RecipeSelections,
        ingredients: [String],
        title: String,
        summary: String
    ) -> String {
        let context = sharedPromptSections(framework: framework, selections: selections)
        let ingredientList = ingredients
            .map { "- \(sanitizePromptText($0))" }
            .joined(separator: "\n")

        let customInstruction = context.customPrompt.isEmpty
            ? ""
            : "\nHonor the user's request while keeping the steps practical for home cooks."

        return sanitizePromptText(
            """
            \(context.sections.joined(separator: "\n\n"))

            Recipe title: \(sanitizePromptText(title))
            Summary: \(sanitizePromptText(summary))

            Ingredients:
            \(ingredientList)

            Write numbered-style steps and tips for this recipe.\(customInstruction)
            Return one JSON object with keys steps and tips only.
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
