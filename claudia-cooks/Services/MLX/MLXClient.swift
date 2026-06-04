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

    var preferredModelName: String? {
        MLXModelPreferenceStore.preferredModelName
    }

    var activeModel: String {
        configuration.resolvedModel(for: systemLoad, preferredModelName: preferredModelName)
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

    func isModelDownloaded(_ modelName: String) async -> Bool {
        await modelCache.isModelDownloaded(
            modelName: modelName,
            configuration: configuration
        )
    }

    func downloadedModels(in modelNames: [String]) async -> Set<String> {
        var downloaded: Set<String> = []

        for modelName in modelNames {
            if await isModelDownloaded(modelName) {
                downloaded.insert(modelName)
            }
        }

        return downloaded
    }

    @discardableResult
    func removeDownloadedModel(_ modelName: String) async throws -> Bool {
        try await modelCache.removeModel(
            modelName: modelName,
            configuration: configuration
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
            macros: nil,
            ingredients: [],
            steps: [],
            tips: []
        )

        let titleSummaryResponse = try await streamChatResponse(
            container: container,
            instructions: titleSummarySystemPrompt(for: framework),
            userMessage: titleSummaryUserPrompt(framework: framework, selections: selections),
            maxTokens: 180
        ) { partialText in
            guard let partial = GeneratedRecipe.decodePartialAssistantResponse(partialText) else {
                return
            }

            if partial.hasMinimumTitleSummaryContent {
                recipe.title = partial.title
                recipe.summary = partial.summary
            }
            onPartialResponse?(recipe)
        }

        guard let titleSummaryRecipe = GeneratedRecipe.decodePartialAssistantResponse(titleSummaryResponse),
              titleSummaryRecipe.hasMinimumTitleSummaryContent else {
            throw MLXClientError.invalidRecipePayload
        }

        recipe.title = titleSummaryRecipe.title
        recipe.summary = titleSummaryRecipe.summary
        onPartialResponse?(recipe)

        let ingredientsResponse = try await streamChatResponse(
            container: container,
            instructions: ingredientsSystemPrompt(for: framework),
            userMessage: ingredientsUserPrompt(
                framework: framework,
                selections: selections,
                title: recipe.title,
                summary: recipe.summary
            ),
            maxTokens: 420
        ) { partialText in
            guard let partial = GeneratedRecipe.decodePartialAssistantResponse(partialText) else {
                return
            }

            if !partial.ingredientEntries.isEmpty {
                recipe.applyStructuredIngredientEntries(partial.ingredientEntries)
            }
            onPartialResponse?(recipe)
        }

        guard let ingredientsRecipe = GeneratedRecipe.decodePartialAssistantResponse(ingredientsResponse),
              ingredientsRecipe.hasMinimumIngredientsListContent else {
            throw MLXClientError.invalidRecipePayload
        }

        recipe.applyStructuredIngredientEntries(ingredientsRecipe.ingredientEntries)
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
        onPartialResponse?(recipe)

        if MacroCalculationsPreferenceStore.isEnabled {
            let macrosResponse = try await streamChatResponse(
                container: container,
                instructions: macrosSystemPrompt(for: framework),
                userMessage: macrosUserPrompt(
                    framework: framework,
                    selections: selections,
                    ingredients: recipe.ingredients,
                    title: recipe.title,
                    summary: recipe.summary
                ),
                maxTokens: 140
            ) { partialText in
                guard let partial = GeneratedRecipe.decodePartialAssistantResponse(partialText),
                      let partialMacros = partial.macros else {
                    return
                }

                var merged = recipe.macros ?? RecipeMacros()
                merged.merge(partialMacros)
                recipe.macros = merged
                onPartialResponse?(recipe)
            }

            guard let macrosRecipe = GeneratedRecipe.decodePartialAssistantResponse(macrosResponse),
                  let macros = macrosRecipe.macros,
                  macros.hasMinimumContent else {
                throw MLXClientError.invalidRecipePayload
            }

            recipe.macros = macros
        }

        guard recipe.hasMinimumRecipeContent else {
            throw MLXClientError.invalidRecipePayload
        }

        if MacroCalculationsPreferenceStore.isEnabled {
            guard recipe.hasMinimumMacrosContent else {
                throw MLXClientError.invalidRecipePayload
            }
        }

        onPartialResponse?(recipe)
        return recipe
    }

    func editRecipe(
        _ recipe: GeneratedRecipe,
        framework: RecipeFramework,
        editPrompt: String
    ) async throws -> RecipeEditPatchResult {
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
            instructions: recipeEditSystemPrompt,
            generateParameters: GenerateParameters(
                maxTokens: 700,
                temperature: 0.1,
                topP: 0.9,
                repetitionPenalty: 1.05
            ),
            additionalContext: ["enable_thinking": false],
            tools: recipeEditToolSchemas
        )

        var response = ""
        var toolCalls: [RecipeEditToolCall] = []
        for try await generation in session.streamDetails(
            to: recipeEditUserPrompt(
                recipe: recipe,
                framework: framework,
                editPrompt: editPrompt
            ),
            images: [],
            videos: []
        ) {
            switch generation {
            case .chunk(let text):
                response += text
            case .toolCall(let toolCall):
                if let editToolCall = recipeEditToolCall(from: toolCall) {
                    toolCalls.append(editToolCall)
                }
            case .info:
                break
            }
        }

        if toolCalls.isEmpty {
            toolCalls = RecipeEditToolCall.decodeAssistantResponse(response) ?? []
        }

        guard !toolCalls.isEmpty else {
            throw MLXClientError.invalidRecipeEditPayload
        }

        let patch = RecipeEditToolCallApplier.apply(toolCalls, to: recipe)
        guard !patch.changes.isEmpty, patch.recipe.hasMinimumRecipeContent else {
            throw MLXClientError.invalidRecipeEditPayload
        }

        return patch
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
                maxTokens: 512,
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
        Assign each ingredient to exactly one category key:
        protein, carbs, produce, dairy, fats, aromatics, spices, acids, liquids, enhancers.
        protein = meat, poultry, seafood, eggs, tofu, beans, lentils.
        carbs = grains, pasta, bread, rice, noodles, starchy roots like potato.
        produce = fresh vegetables and fruit used as vegetables.
        dairy = milk, cheese, yogurt, cream.
        fats = oils, butter, ghee, lard, rendered fat.
        aromatics = garlic, onion, ginger, shallot, fresh chiles used for base flavor.
        spices = dried spices and dried herbs (not fresh herb garnishes).
        acids = vinegar, citrus juice, pickled brine used for acidity.
        liquids = broth, stock, wine, water, coconut milk as a cooking liquid.
        enhancers = soy sauce, fish sauce, miso, mustard, Worcestershire, umami pastes and condiments.
        Reply with a single JSON object only. No markdown, no code fences, no commentary.
        Do not prepend the ingredients with adjectives like "chopped", "sliced", "diced", etc.
        Example: {"chicken breasts":"protein","olive oil":"fats","lemon juice":"acids","soy sauce":"enhancers"}
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

            guard let rawValue, let category = IngredientCategory(storageKey: rawValue) else {
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

        guard !MLXModelPreferenceStore.hasExplicitPreferredModel,
              let alternate = configuration.alternateBuiltInModelName(for: activeModel) else {
            return nil
        }

        if await isModelAvailable(alternate) {
            return alternate
        }

        return nil
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

    private var preferredMeasurementSystem: CookingMeasurementSystem? {
        CookingMeasurementPreferenceStore.preferredSystem
    }

    private var measurementSystemPromptSuffix: String {
        guard let preferredMeasurementSystem else {
            return ""
        }

        return "\n\(preferredMeasurementSystem.systemPromptInstruction)"
    }

    private var languagePromptSuffix: String {
        guard let instruction = RecipeGenerationLanguagePreferenceStore.preferredLanguage.systemPromptInstruction else {
            return ""
        }

        return "\n\(instruction)"
    }

    private var recipeGenerationPromptSuffix: String {
        "\(languagePromptSuffix)\(measurementSystemPromptSuffix)"
    }

    private var recipeEditPromptSuffix: String {
        let ingredientsSuffix = preferredGenerationLanguage.ingredientsSystemPromptInstruction
            .map { "\n\($0)" } ?? ""
        return "\(languagePromptSuffix)\(ingredientsSuffix)\(measurementSystemPromptSuffix)"
    }

    private var preferredGenerationLanguage: RecipeGenerationLanguage {
        RecipeGenerationLanguagePreferenceStore.preferredLanguage
    }

    private var ingredientsLanguagePromptSuffix: String {
        guard let instruction = preferredGenerationLanguage.ingredientsSystemPromptInstruction else {
            return measurementSystemPromptSuffix
        }

        return "\n\(instruction)\(measurementSystemPromptSuffix)"
    }

    private var ingredientQuantityExampleHint: String {
        preferredMeasurementSystem?.ingredientQuantityExampleHint
            ?? "e.g. \"2\", \"1 tbsp\", \"200 g\""
    }

    private var ingredientJSONExample: String {
        preferredGenerationLanguage.ingredientJSONExample(measurementSystem: preferredMeasurementSystem)
    }

    private func titleSummarySystemPrompt(for framework: RecipeFramework) -> String {
        """
        You are a practical cooking assistant for home cooks.
        \(framework.mlxCategoryGuidance)
        Write a concise recipe title and one-sentence summary for a \(framework.title.lowercased()) dish (\(framework.dishExamples)) from the user's selections.
        The title should sound like a real dish in this category, not a generic list of ingredients.
        Use only the selected ingredients plus common pantry staples such as salt, pepper, oil, water, and vinegar ONLY if applicable.
        Do not invent unavailable specialty ingredients.\(recipeGenerationPromptSuffix)
        Reply with a single JSON object only. No markdown, no code fences, no commentary, no thinking tags.
        Required keys: title, summary.
        Example shape:
        {"title":"Garlic Herb Chicken","summary":"A quick skillet dinner with crisp skin and fresh herbs."}
        """
    }

    private func ingredientsSystemPrompt(for framework: RecipeFramework) -> String {
        """
        You are a practical cooking assistant for home cooks.
        \(framework.mlxCategoryGuidance)
        Generate the ingredient list for a concise \(framework.title.lowercased()) dish (\(framework.dishExamples)) from the user's selections.
        List amounts appropriate to the dish style (e.g. enough broth for soup, enough bread for handhelds, enough starch for a bowl).
        Use only the selected ingredients plus common pantry staples such as salt, pepper, oil, water, and vinegar ONLY if applicable.
        Do not invent unavailable specialty ingredients.\(ingredientsLanguagePromptSuffix)
        Reply with a single JSON object only. No markdown, no code fences, no commentary, no thinking tags.
        Required key: ingredients.
        ingredients must be a JSON array of objects. Each object requires "name" (ingredient only, no amount, no variant, e.g. "\(preferredGenerationLanguage.ingredientNameFieldExample)").
        Include "quantity" (\(ingredientQuantityExampleHint)) and ensure that measurements are included when applicable to the ingredient.
        Include "variant" only when a catalog ingredient has multiple types and you need to disambiguate which type you used (e.g. "\(preferredGenerationLanguage.ingredientVariantFieldExample)"); omit it otherwise.
        The app concatenates quantity, variant, and name for markdown in a natural order (e.g. quantity "2" + variant "\(preferredGenerationLanguage.ingredientVariantFieldExample)" + name "\(preferredGenerationLanguage.ingredientNameFieldExample)").
        Example shape:
        \(ingredientJSONExample)
        """
    }

    private func macrosSystemPrompt(for framework: RecipeFramework) -> String {
        """
        You are a practical cooking assistant for home cooks.
        \(framework.mlxCategoryGuidance)
        Estimate nutrition for a \(framework.title.lowercased()) dish (\(framework.dishExamples)) from its title, summary, and ingredient list.
        Use realistic home-cook portion sizes. Prefer yields of 2–4 servings unless the dish clearly serves more or less.
        Return approximate per-serving values as whole numbers (round calories to the nearest 5 when helpful).
        Reply with a single JSON object only. No markdown, no code fences, no commentary, no thinking tags.
        Required keys: servings, calories, protein_g, carbs_g, fat_g.
        Example shape:
        {"servings":4,"calories":520,"protein_g":38,"carbs_g":42,"fat_g":22}
        """
    }

    private func instructionsSystemPrompt(for framework: RecipeFramework) -> String {
        """
        You are a practical cooking assistant for home cooks.
        \(framework.mlxCategoryGuidance)
        Write clear, safe, realistic cooking instructions for a \(framework.title.lowercased()) dish (\(framework.dishExamples)).
        Steps must follow the techniques and sequencing best suited to this category (e.g. assembly order for handhelds, simmer stages for soups, high-heat workflow for sautés).
        Use the provided ingredient list exactly; do not add new ingredients beyond common pantry staples already listed.
        When mentioning amounts in steps, use the same measurement units as the ingredient list.\(recipeGenerationPromptSuffix)
        Reply with a single JSON object only. No markdown, no code fences, no commentary, no thinking tags.
        Required keys: steps, tips.
        steps and tips must be JSON arrays of strings.
        Example shape:
        {"steps":["Season the chicken.","Sear until golden, then finish in the oven."],"tips":["Rest before slicing."]}
        """
    }

    private var recipeEditSystemPrompt: String {
        """
        You edit generated recipes by calling recipe patch tools.
        Use tool calls only. Do not reply with a full rewritten recipe, markdown, commentary, or thinking tags.

        Supported tool call names:
        set_title, set_summary,
        add_ingredient, replace_ingredient, remove_ingredient,
        add_step, replace_step, remove_step,
        add_tip, replace_tip, remove_tip.

        Use 1-based indexes. For replacements and removals, include the original text in "from".
        For additions and replacements, include the new text in "to".
        Return only the smallest set of tool calls needed to satisfy the user's edit request.\(recipeEditPromptSuffix)
        """
    }

    private var recipeEditToolSchemas: [ToolSpec] {
        let indexProperty = [
            "type": "integer",
            "description": "1-based position in the recipe section."
        ] as [String: any Sendable]
        let fromProperty = [
            "type": "string",
            "description": "The exact original text being replaced or removed."
        ] as [String: any Sendable]
        let toProperty = [
            "type": "string",
            "description": "The new text to add or replace with."
        ] as [String: any Sendable]

        return [
            recipeEditToolSchema(
                name: "set_title",
                description: "Replace the recipe title.",
                properties: ["to": toProperty],
                required: ["to"]
            ),
            recipeEditToolSchema(
                name: "set_summary",
                description: "Replace the recipe summary.",
                properties: ["to": toProperty],
                required: ["to"]
            ),
            recipeEditToolSchema(
                name: "add_ingredient",
                description: "Add an ingredient line.",
                properties: ["index": indexProperty, "to": toProperty],
                required: ["to"]
            ),
            recipeEditToolSchema(
                name: "replace_ingredient",
                description: "Replace an existing ingredient line.",
                properties: ["index": indexProperty, "from": fromProperty, "to": toProperty],
                required: ["to"]
            ),
            recipeEditToolSchema(
                name: "remove_ingredient",
                description: "Remove an ingredient line.",
                properties: ["index": indexProperty, "from": fromProperty],
                required: []
            ),
            recipeEditToolSchema(
                name: "add_step",
                description: "Add a recipe step.",
                properties: ["index": indexProperty, "to": toProperty],
                required: ["to"]
            ),
            recipeEditToolSchema(
                name: "replace_step",
                description: "Replace an existing recipe step.",
                properties: ["index": indexProperty, "from": fromProperty, "to": toProperty],
                required: ["to"]
            ),
            recipeEditToolSchema(
                name: "remove_step",
                description: "Remove a recipe step.",
                properties: ["index": indexProperty, "from": fromProperty],
                required: []
            ),
            recipeEditToolSchema(
                name: "add_tip",
                description: "Add a recipe tip.",
                properties: ["index": indexProperty, "to": toProperty],
                required: ["to"]
            ),
            recipeEditToolSchema(
                name: "replace_tip",
                description: "Replace an existing recipe tip.",
                properties: ["index": indexProperty, "from": fromProperty, "to": toProperty],
                required: ["to"]
            ),
            recipeEditToolSchema(
                name: "remove_tip",
                description: "Remove a recipe tip.",
                properties: ["index": indexProperty, "from": fromProperty],
                required: []
            )
        ]
    }

    private func recipeEditToolSchema(
        name: String,
        description: String,
        properties: [String: any Sendable],
        required: [String]
    ) -> ToolSpec {
        [
            "type": "function",
            "function": [
                "name": name,
                "description": description,
                "parameters": [
                    "type": "object",
                    "properties": properties,
                    "required": required
                ] as [String: any Sendable]
            ] as [String: any Sendable]
        ] as ToolSpec
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

    private func titleSummaryUserPrompt(framework: RecipeFramework, selections: RecipeSelections) -> String {
        let context = sharedPromptSections(framework: framework, selections: selections)

        let ingredientInstruction = context.ingredientLines.isEmpty
            ? ""
            : "\nBase the title and summary on the selected ingredients, plus common pantry staples only when needed."

        let customInstruction = context.customPrompt.isEmpty
            ? ""
            : "\nHonor the user's request while keeping the recipe practical for home cooks."

        return sanitizePromptText(
            """
            \(context.sections.joined(separator: "\n\n"))

            Generate the recipe title and summary.\(ingredientInstruction)\(customInstruction)
            Return one JSON object with keys title and summary only.
            Start with { and end with }. Do not wrap the JSON in markdown.
            """
        )
    }

    private func ingredientsUserPrompt(
        framework: RecipeFramework,
        selections: RecipeSelections,
        title: String,
        summary: String
    ) -> String {
        let context = sharedPromptSections(framework: framework, selections: selections)

        let ingredientInstruction = context.ingredientLines.isEmpty
            ? ""
            : "\nUse only the selected ingredients, plus common pantry staples such as salt, pepper, oil, water, and vinegar ONLY when applicable."

        let variantInstruction = variantSelectionPromptLines(
            for: selections,
            categories: framework.applicableCategories,
            language: preferredGenerationLanguage
        )

        let languageInstruction = ingredientsUserPromptLanguageInstruction

        let customInstruction = context.customPrompt.isEmpty
            ? ""
            : "\nHonor the user's request while keeping the recipe practical for home cooks."

        return sanitizePromptText(
            """
            \(context.sections.joined(separator: "\n\n"))

            Recipe title: \(sanitizePromptText(title))
            Summary: \(sanitizePromptText(summary))

            Generate the ingredient list for this recipe.\(ingredientInstruction)\(variantInstruction)\(languageInstruction)\(customInstruction)
            Return one JSON object with key ingredients only.
            Each ingredient is an object with "name" (no amount), optional "quantity", and optional "variant" (only for typed catalog items).
            Start with { and end with }. Do not wrap the JSON in markdown.
            """
        )
    }

    private var ingredientsUserPromptLanguageInstruction: String {
        guard let instruction = preferredGenerationLanguage.ingredientsSystemPromptInstruction else {
            return ""
        }

        return "\n\(instruction)"
    }

    private func variantSelectionPromptLines(
        for selections: RecipeSelections,
        categories: [IngredientCategory],
        language: RecipeGenerationLanguage
    ) -> String {
        let lines = categories.flatMap { category -> [String] in
            selections.selectedOptions[category, default: []].compactMap { selection -> String? in
                guard let variant = IngredientSelectionLabel.variantLabel(from: selection) else {
                    return nil
                }

                let base = IngredientSelectionLabel.baseOption(from: selection)
                return "- \(sanitizePromptText(base)): user chose variant \"\(sanitizePromptText(variant))\""
            }
        }

        guard !lines.isEmpty else {
            return ""
        }

        let variantLanguageClause = language == .english
            ? "set \"variant\" on that ingredient object to match the user's chosen type:"
            : "set \"variant\" on that ingredient object to the \(language.promptLanguageName) equivalent of the user's chosen type (translate from the English labels below):"

        return """

        When an ingredient below has a chosen variant, \(variantLanguageClause)
        \(lines.joined(separator: "\n"))
        """
    }

    private func macrosUserPrompt(
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

        return sanitizePromptText(
            """
            \(context.sections.joined(separator: "\n\n"))

            Recipe title: \(sanitizePromptText(title))
            Summary: \(sanitizePromptText(summary))

            Ingredients:
            \(ingredientList)

            Estimate per-serving nutrition for this recipe.
            Return one JSON object with keys servings, calories, protein_g, carbs_g, and fat_g only.
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

    private func recipeEditUserPrompt(
        recipe: GeneratedRecipe,
        framework: RecipeFramework,
        editPrompt: String
    ) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let recipeJSON = (try? encoder.encode(recipe))
            .flatMap { String(data: $0, encoding: .utf8) }
            ?? "{}"

        return """
        Framework: \(sanitizePromptText(framework.title))

        Current recipe JSON:
        \(recipeJSON)

        User edit request:
        \(sanitizePromptText(editPrompt))

        Call the smallest set of recipe edit tools needed to satisfy the request. Do not include unchanged content.
        """
    }

    private func recipeEditToolCall(from toolCall: ToolCall) -> RecipeEditToolCall? {
        let arguments = toolCall.function.arguments
        let editArguments = RecipeEditToolArguments(
            index: intArgument(["index", "position"], from: arguments),
            from: stringArgument(["from", "oldText", "old_text", "before"], from: arguments),
            to: stringArgument(["to", "newText", "new_text", "after"], from: arguments),
            text: stringArgument(["text"], from: arguments),
            value: stringArgument(["value"], from: arguments),
            title: stringArgument(["title"], from: arguments),
            summary: stringArgument(["summary"], from: arguments)
        )

        return RecipeEditToolCall(
            name: toolCall.function.name,
            arguments: editArguments
        )
    }

    private func stringArgument(
        _ keys: [String],
        from arguments: [String: JSONValue]
    ) -> String? {
        for key in keys {
            guard let value = arguments[key] else {
                continue
            }

            let stringValue: String?
            switch value {
            case .string(let string):
                stringValue = string
            case .int(let int):
                stringValue = String(int)
            case .double(let double):
                stringValue = String(double)
            case .bool(let bool):
                stringValue = String(bool)
            default:
                stringValue = nil
            }

            if let stringValue {
                let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
        }

        return nil
    }

    private func intArgument(
        _ keys: [String],
        from arguments: [String: JSONValue]
    ) -> Int? {
        for key in keys {
            guard let value = arguments[key] else {
                continue
            }

            switch value {
            case .int(let int):
                return int
            case .double(let double):
                return Int(double)
            case .string(let string):
                if let int = Int(string.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    return int
                }
            default:
                continue
            }
        }

        return nil
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
    case invalidRecipeEditPayload
    case invalidCategoryPayload

    var errorDescription: String? {
        switch self {
        case .invalidModelIdentifier(let model):
            "MLX model identifier is invalid: \(model)"
        case .modelNotFound(let model):
            "\(model) is not downloaded yet. Choose a model size to download the MLX model files."
        case .invalidRecipePayload:
            "The recipe JSON from MLX could not be decoded. Try generating again."
        case .invalidRecipeEditPayload:
            "The recipe edit from MLX could not be applied. Try a more specific edit request."
        case .invalidCategoryPayload:
            "MLX could not classify one or more ingredients. Try again after the model finishes loading."
        }
    }
}
