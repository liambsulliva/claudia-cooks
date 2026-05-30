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
    var selections = RecipeSelections()
    var pdfData: Data
    var isGenerating = false
    var errorMessage: String?

    @ObservationIgnored var onRecipeGenerated: ((GeneratedRecipe, Data) -> Void)?
    @ObservationIgnored var onPDFDataChanged: ((Data) -> Void)?
    var mlxSetup: MLXSetupViewModel
    @ObservationIgnored private let generationService: RecipeGenerationService
    @ObservationIgnored private var debounceTask: Task<Void, Never>?
    @ObservationIgnored private var generationRequestID = 0
    @ObservationIgnored private var lastStreamRenderInstant: ContinuousClock.Instant?

    init(
        framework: RecipeFramework,
        generationService: RecipeGenerationService? = nil,
        mlxSetup: MLXSetupViewModel? = nil
    ) {
        let initialSelections = RecipeSelections()
        let service = generationService ?? RecipeGenerationService()
        let setup = mlxSetup ?? MLXSetupViewModel(generationService: service)

        self.framework = framework
        self.selections = initialSelections
        self.generationService = service
        self.mlxSetup = setup
        self.pdfData = RecipePDFRenderer.renderSelectionPreview(
            framework: framework,
            selections: initialSelections,
            message: nil
        )

        setup.onModelReady = { [weak self] in
            guard let self, self.selections.canGenerate else {
                return
            }
            self.scheduleGeneration()
        }

        Task {
            await setup.refreshAvailability()
            self.syncPreviewMessage()
        }
    }

    deinit {
        debounceTask?.cancel()
    }

    func toggle(_ option: String, in category: IngredientCategory) {
        selections.toggle(option, in: category)
        scheduleGeneration()
    }

    func setOtherText(_ text: String, for category: IngredientCategory) {
        selections.setOtherText(text, for: category)
        scheduleGeneration()
    }

    func setCustomPrompt(_ text: String) {
        selections.customPrompt = text
        scheduleGeneration()
    }

    func scheduleGeneration() {
        debounceTask?.cancel()
        generationRequestID += 1
        let requestID = generationRequestID
        let framework = framework
        let selections = selections

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
                selections: selections
            )
        }
    }

    private func performGeneration(
        requestID: Int,
        framework: RecipeFramework,
        selections: RecipeSelections
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

        guard selections.canGenerate else {
            isGenerating = false
            updateSelectionPreview(message: mlxSetup.modelAvailability)
            return
        }

        if mlxSetup.modelAvailability != nil {
            isGenerating = false
            updateSelectionPreview(message: mlxSetup.modelAvailability)
            return
        }

        isGenerating = true
        lastStreamRenderInstant = nil

        do {
            let recipe = try await generationService.generateRecipe(
                framework: framework,
                selections: selections
            ) { [weak self] partialResponse in
                Task { @MainActor in
                    self?.renderStreamingPreview(
                        partialResponse: partialResponse,
                        requestID: requestID,
                        framework: framework,
                        selections: selections
                    )
                }
            }

            guard requestID == generationRequestID else {
                return
            }

            let renderedPDF = RecipePDFRenderer.render(
                recipe: recipe,
                framework: framework,
                selections: selections
            )
            setPDFData(renderedPDF)
            onRecipeGenerated?(recipe, renderedPDF)
            isGenerating = false
        } catch {
            guard requestID == generationRequestID, !Self.isBenignCancellation(error) else {
                return
            }

            isGenerating = false
            errorMessage = Self.userFacingGenerationError(error)
            updateSelectionPreview(message: errorMessage)
        }
    }

    private func setPDFData(_ data: Data) {
        pdfData = data
        onPDFDataChanged?(data)
    }

    private func updateSelectionPreview(message: String?) {
        setPDFData(
            RecipePDFRenderer.renderSelectionPreview(
                framework: framework,
                selections: selections,
                message: message
            )
        )
    }

    private func syncPreviewMessage() {
        if let modelAvailability = mlxSetup.modelAvailability {
            updateSelectionPreview(message: modelAvailability)
        }
    }

    private func renderStreamingPreview(
        partialResponse: String,
        requestID: Int,
        framework: RecipeFramework,
        selections: RecipeSelections
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

        guard let partialRecipe = GeneratedRecipe.decodePartialAssistantResponse(partialResponse) else {
            return
        }

        setPDFData(
            RecipePDFRenderer.render(
                recipe: partialRecipe,
                framework: framework,
                selections: selections
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

        return "Recipe generation failed. Showing your current selections instead."
    }
}
