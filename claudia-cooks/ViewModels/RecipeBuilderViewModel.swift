//
//  RecipeBuilderViewModel.swift
//  claudia-cooks
//

import Foundation
import Observation

@MainActor
@Observable
final class RecipeBuilderViewModel {
    let framework: RecipeFramework
    var selections: RecipeSelections
    var recipeMarkdown: String
    var isGenerating = false
    var errorMessage: String?

    @ObservationIgnored var onRecipeGenerated: ((GeneratedRecipe, String) -> Void)?
    @ObservationIgnored var onRecipeMarkdownChanged: ((String) -> Void)?
    @ObservationIgnored var onRecipeDocumentCleared: (() -> Void)?
    @ObservationIgnored var onSelectionsChanged: ((RecipeSelections) -> Void)?
    var mlxSetup: MLXSetupViewModel
    @ObservationIgnored private let generationService: RecipeGenerationService
    @ObservationIgnored private var debounceTask: Task<Void, Never>?
    @ObservationIgnored private var makeupDebounceTask: Task<Void, Never>?
    @ObservationIgnored private var generationRequestID = 0
    @ObservationIgnored private var lastStreamRenderInstant: ContinuousClock.Instant?
    @ObservationIgnored private var lastGeneratedMakeup: IngredientMakeup?

    init(
        framework: RecipeFramework,
        initialSelections: RecipeSelections = RecipeSelections(),
        initialMarkdown: String? = nil,
        hadPersistedGeneratedRecipe: Bool = false,
        generationService: RecipeGenerationService? = nil,
        mlxSetup: MLXSetupViewModel? = nil
    ) {
        let service = generationService ?? RecipeGenerationService()
        let setup = mlxSetup ?? MLXSetupViewModel(generationService: service)

        self.framework = framework
        self.selections = initialSelections
        self.generationService = service
        self.mlxSetup = setup
        self.recipeMarkdown = initialMarkdown ?? ""
        self.lastGeneratedMakeup = hadPersistedGeneratedRecipe
            ? initialSelections.ingredientMakeup
            : nil

        setup.onModelReady = { [weak self] in
            guard let self, !self.selections.ingredientMakeup.isEmpty else {
                return
            }
            self.scheduleGenerationIfMakeupChanged()
        }

        Task {
            await setup.refreshAvailability()
            self.syncPreviewMessage()
        }
    }

    deinit {
        debounceTask?.cancel()
        makeupDebounceTask?.cancel()
    }

    func toggle(_ option: String, in category: IngredientCategory) {
        selections.toggle(option, in: category)
        persistSelectionsAndRefreshPreview()
        scheduleGenerationIfMakeupChanged()
    }

    func toggleVariant(_ variant: String, for base: String, in category: IngredientCategory) {
        selections.toggle(base: base, variant: variant, in: category)
        persistSelectionsAndRefreshPreview()
        scheduleGenerationIfMakeupChanged()
    }

    func setOtherText(_ text: String, for category: IngredientCategory) {
        selections.setOtherText(text, for: category)
        persistSelectionsAndRefreshPreview()
        scheduleGenerationIfMakeupChanged(debounced: true)
    }

    func loadRecipeState(
        selections newSelections: RecipeSelections,
        hadPersistedGeneratedRecipe: Bool
    ) {
        debounceTask?.cancel()
        makeupDebounceTask?.cancel()
        generationRequestID += 1
        isGenerating = false
        errorMessage = nil

        selections = newSelections
        lastGeneratedMakeup = hadPersistedGeneratedRecipe
            ? newSelections.ingredientMakeup
            : nil

        if hadPersistedGeneratedRecipe {
            syncPreviewMessage()
        } else {
            recipeMarkdown = ""
        }
    }

    func submitRecipePrompt(_ prompt: String) {
        selections.customPrompt = prompt
        clearIngredientSelections()
        persistSelectionsAndRefreshPreview()
        scheduleGeneration(force: true)
    }

    private func clearIngredientSelections() {
        selections.selectedOptions = [:]
        selections.otherText = [:]
    }

    private func persistSelectionsAndRefreshPreview() {
        onSelectionsChanged?(selections)

        if selections.ingredientMakeup.isEmpty {
            if selections.normalizedCustomPrompt.isEmpty {
                resetPreviewAndClearDocument()
            }
            return
        }

        if selections.ingredientMakeup != lastGeneratedMakeup {
            cancelActiveGeneration()
            setRecipeMarkdown("")
        }
    }

    private func resetPreviewAndClearDocument() {
        cancelActiveGeneration()
        lastGeneratedMakeup = nil
        setRecipeMarkdown("")
        onRecipeDocumentCleared?()
    }

    private func cancelActiveGeneration() {
        debounceTask?.cancel()
        makeupDebounceTask?.cancel()
        generationRequestID += 1
        isGenerating = false
        lastStreamRenderInstant = nil
    }

    private func scheduleGenerationIfMakeupChanged(debounced: Bool = false) {
        if debounced {
            makeupDebounceTask?.cancel()
            makeupDebounceTask = Task { [weak self] in
                do {
                    try await Task.sleep(for: .milliseconds(300))
                } catch {
                    return
                }

                guard let self else {
                    return
                }

                self.scheduleGenerationIfMakeupChanged()
            }
            return
        }

        guard !selections.ingredientMakeup.isEmpty,
              selections.ingredientMakeup != lastGeneratedMakeup else {
            return
        }

        scheduleGeneration()
    }

    func scheduleGeneration(force: Bool = false) {
        debounceTask?.cancel()
        generationRequestID += 1
        let requestID = generationRequestID
        let framework = framework
        let selections = selections
        let forceGeneration = force

        debounceTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(250))
            } catch {
                return
            }

            guard let self, requestID == self.generationRequestID else {
                return
            }

            await self.performGeneration(
                requestID: requestID,
                framework: framework,
                selections: selections,
                force: forceGeneration
            )
        }
    }

    private func performGeneration(
        requestID: Int,
        framework: RecipeFramework,
        selections: RecipeSelections,
        force: Bool
    ) async {
        guard requestID == generationRequestID else {
            return
        }

        if generationService.lastAvailability == nil {
            await mlxSetup.refreshAvailability()
        }

        guard requestID == generationRequestID else {
            return
        }

        errorMessage = nil

        guard selections.hasGenerationInput else {
            isGenerating = false
            return
        }

        if !force {
            guard !selections.ingredientMakeup.isEmpty,
                  selections.ingredientMakeup != lastGeneratedMakeup else {
                isGenerating = false
                return
            }
        }

        if mlxSetup.modelAvailability != nil {
            isGenerating = false
            return
        }

        isGenerating = true
        lastStreamRenderInstant = nil

        do {
            let recipe = try await generationService.generateRecipe(
                framework: framework,
                selections: selections
            ) { [weak self] partialRecipe in
                Task { @MainActor in
                    self?.renderStreamingPreview(
                        partialRecipe: partialRecipe,
                        requestID: requestID,
                        framework: framework
                    )
                }
            }

            guard requestID == generationRequestID else {
                return
            }

            let renderedMarkdown = RecipeMarkdownRenderer.render(
                recipe: recipe,
                framework: framework
            )
            setRecipeMarkdown(renderedMarkdown)
            lastGeneratedMakeup = selections.ingredientMakeup
            onRecipeGenerated?(recipe, renderedMarkdown)
            isGenerating = false
        } catch {
            guard requestID == generationRequestID, !Self.isBenignCancellation(error) else {
                return
            }

            isGenerating = false
            errorMessage = Self.userFacingGenerationError(error)
        }
    }

    func updateRecipeMarkdown(_ markdown: String) {
        recipeMarkdown = markdown
        onRecipeMarkdownChanged?(markdown)
    }

    private func setRecipeMarkdown(_ markdown: String) {
        updateRecipeMarkdown(markdown)
    }

    private func syncPreviewMessage() {
        errorMessage = mlxSetup.modelAvailability
    }

    private func renderStreamingPreview(
        partialRecipe: GeneratedRecipe,
        requestID: Int,
        framework: RecipeFramework
    ) {
        guard requestID == generationRequestID else {
            return
        }

        let now = ContinuousClock.now
        if let lastStreamRenderInstant,
           now - lastStreamRenderInstant < .milliseconds(120) {
            return
        }
        lastStreamRenderInstant = now

        setRecipeMarkdown(
            RecipeMarkdownRenderer.render(
                recipe: partialRecipe,
                framework: framework
            )
        )
    }

    private static func isBenignCancellation(_ error: Error) -> Bool {
        error is CancellationError
    }

    private static func userFacingGenerationError(_ error: Error) -> String {
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription,
           !description.isEmpty {
            return description
        }

        return "Recipe generation failed. Try again from the builder panel."
    }
}
