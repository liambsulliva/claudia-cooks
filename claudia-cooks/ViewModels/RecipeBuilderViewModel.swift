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
    var currentRecipe: GeneratedRecipe?
    var pendingRecipeEdit: RecipeEditPendingDiff?
    /// Bumped when undo/redo restores recipe review state so the preview reloads.
    private(set) var recipeEditReviewUndoRevision = 0
    var isGenerating = false
    var errorMessage: String?

    var canEditGeneratedRecipe: Bool {
        currentRecipe?.hasMinimumRecipeContent == true && !isGenerating
    }

    var hasPendingRecipeEdit: Bool {
        pendingRecipeEdit?.hasChanges == true
    }

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
    @ObservationIgnored private let recipeEditUndoManager = UndoManager()

    var recipeEditUndoManagerForPreview: UndoManager {
        recipeEditUndoManager
    }

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
        self.currentRecipe = initialMarkdown.flatMap {
            RecipeMarkdownRecipeParser.parse($0, framework: framework)
        }
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
        currentRecipe = nil
        pendingRecipeEdit = nil
        lastGeneratedMakeup = hadPersistedGeneratedRecipe
            ? newSelections.ingredientMakeup
            : nil

        if hadPersistedGeneratedRecipe {
            syncPreviewMessage()
        } else {
            currentRecipe = nil
            recipeMarkdown = ""
        }
    }

    func submitRecipePrompt(_ prompt: String) {
        pendingRecipeEdit = nil
        selections.customPrompt = prompt
        clearIngredientSelections()
        persistSelectionsAndRefreshPreview()
        scheduleGeneration(force: true)
    }

    func submitRecipeEditPrompt(_ prompt: String) {
        let editPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !editPrompt.isEmpty else {
            return
        }

        let recipe = currentRecipe ?? pendingRecipeEdit?.originalRecipe
        guard let recipe else {
            return
        }

        scheduleRecipeEdit(recipe: recipe, editPrompt: editPrompt)
    }

    func acceptPendingRecipeEditChange(_ changeID: UUID) {
        guard var pendingRecipeEdit,
              let changeIndex = pendingRecipeEdit.changes.firstIndex(where: { $0.id == changeID }) else {
            return
        }

        registerRecipeEditUndo()

        let change = pendingRecipeEdit.changes.remove(at: changeIndex)
        let updatedRecipe = RecipeEditToolCallApplier.apply(
            change,
            to: currentRecipe ?? pendingRecipeEdit.originalRecipe
        )

        commitRecipeEdit(updatedRecipe)

        if pendingRecipeEdit.changes.isEmpty {
            self.pendingRecipeEdit = nil
        } else {
            pendingRecipeEdit.originalRecipe = updatedRecipe
            self.pendingRecipeEdit = pendingRecipeEdit
        }
    }

    func denyPendingRecipeEditChange(_ changeID: UUID) {
        guard var pendingRecipeEdit else {
            return
        }

        registerRecipeEditUndo()

        pendingRecipeEdit.changes.removeAll { $0.id == changeID }

        if pendingRecipeEdit.changes.isEmpty {
            self.pendingRecipeEdit = nil
        } else {
            self.pendingRecipeEdit = pendingRecipeEdit
        }
    }

    func acceptAllPendingRecipeEditChanges() {
        guard let pendingRecipeEdit else {
            return
        }

        registerRecipeEditUndo()

        commitRecipeEdit(pendingRecipeEdit.proposedRecipe)
        self.pendingRecipeEdit = nil
    }

    func updateRecipeDuringPendingEdit(_ update: PendingDiffMarkdownUpdate) {
        guard var pendingRecipeEdit,
              let parsedRecipe = RecipeMarkdownRecipeParser.parse(update.markdown, framework: framework) else {
            return
        }

        pendingRecipeEdit.originalRecipe = parsedRecipe

        for edit in update.additions {
            guard let changeID = UUID(uuidString: edit.id),
                  let changeIndex = pendingRecipeEdit.changes.firstIndex(where: { $0.id == changeID }) else {
                continue
            }

            pendingRecipeEdit.changes[changeIndex].after = edit.text
        }

        self.pendingRecipeEdit = pendingRecipeEdit
        currentRecipe = parsedRecipe
    }

    private struct RecipeEditUndoSnapshot {
        var pendingRecipeEdit: RecipeEditPendingDiff?
        var recipeMarkdown: String
        var currentRecipe: GeneratedRecipe?
    }

    private func captureRecipeEditSnapshot() -> RecipeEditUndoSnapshot {
        RecipeEditUndoSnapshot(
            pendingRecipeEdit: pendingRecipeEdit,
            recipeMarkdown: recipeMarkdown,
            currentRecipe: currentRecipe
        )
    }

    private func restoreRecipeEditSnapshot(_ snapshot: RecipeEditUndoSnapshot) {
        pendingRecipeEdit = snapshot.pendingRecipeEdit
        recipeMarkdown = snapshot.recipeMarkdown
        currentRecipe = snapshot.currentRecipe
        recipeEditReviewUndoRevision += 1
        onRecipeMarkdownChanged?(recipeMarkdown)
    }

    private func registerRecipeEditUndo() {
        let snapshot = captureRecipeEditSnapshot()
        recipeEditUndoManager.registerUndo(withTarget: self) { viewModel in
            let currentSnapshot = viewModel.captureRecipeEditSnapshot()
            viewModel.restoreRecipeEditSnapshot(snapshot)
            viewModel.registerRecipeEditUndoRestoring(to: currentSnapshot)
        }
        recipeEditUndoManager.setActionName("Review Recipe Change")
    }

    private func registerRecipeEditUndoRestoring(to snapshot: RecipeEditUndoSnapshot) {
        recipeEditUndoManager.registerUndo(withTarget: self) { viewModel in
            let currentSnapshot = viewModel.captureRecipeEditSnapshot()
            viewModel.restoreRecipeEditSnapshot(snapshot)
            viewModel.registerRecipeEditUndoRestoring(to: currentSnapshot)
        }
        recipeEditUndoManager.setActionName("Review Recipe Change")
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
            currentRecipe = nil
            pendingRecipeEdit = nil
            setRecipeMarkdown("")
        }
    }

    private func resetPreviewAndClearDocument() {
        cancelActiveGeneration()
        lastGeneratedMakeup = nil
        currentRecipe = nil
        pendingRecipeEdit = nil
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

    private func scheduleRecipeEdit(recipe: GeneratedRecipe, editPrompt: String) {
        debounceTask?.cancel()
        generationRequestID += 1
        let requestID = generationRequestID
        let framework = framework
        let selections = selections

        debounceTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(150))
            } catch {
                return
            }

            guard let self, requestID == self.generationRequestID else {
                return
            }

            await self.performRecipeEdit(
                requestID: requestID,
                framework: framework,
                selections: selections,
                recipe: recipe,
                editPrompt: editPrompt
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
        pendingRecipeEdit = nil

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
            var committedRecipe = recipe
            committedRecipe.syncIngredientsFromEntries()
            currentRecipe = committedRecipe
            setRecipeMarkdown(renderedMarkdown, structuredRecipe: committedRecipe)
            lastGeneratedMakeup = selections.ingredientMakeup
            onRecipeGenerated?(committedRecipe, renderedMarkdown)
            isGenerating = false
        } catch {
            guard requestID == generationRequestID, !Self.isBenignCancellation(error) else {
                return
            }

            isGenerating = false
            errorMessage = Self.userFacingGenerationError(error)
        }
    }

    private func performRecipeEdit(
        requestID: Int,
        framework: RecipeFramework,
        selections: RecipeSelections,
        recipe: GeneratedRecipe,
        editPrompt: String
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

        guard mlxSetup.modelAvailability == nil else {
            isGenerating = false
            return
        }

        isGenerating = true
        lastStreamRenderInstant = nil

        do {
            let patch = try await generationService.editRecipe(
                recipe,
                framework: framework,
                editPrompt: editPrompt
            )

            guard requestID == generationRequestID else {
                return
            }

            if var existingPendingEdit = pendingRecipeEdit, existingPendingEdit.hasChanges {
                existingPendingEdit.changes.append(contentsOf: patch.changes)
                existingPendingEdit.proposedRecipe = Self.recipe(
                    byApplying: existingPendingEdit.changes,
                    to: existingPendingEdit.originalRecipe
                )
                pendingRecipeEdit = existingPendingEdit
            } else {
                pendingRecipeEdit = RecipeEditPendingDiff(
                    originalRecipe: recipe,
                    proposedRecipe: patch.recipe,
                    changes: patch.changes
                )
            }
            isGenerating = false
        } catch {
            guard requestID == generationRequestID, !Self.isBenignCancellation(error) else {
                return
            }

            isGenerating = false
            errorMessage = Self.userFacingGenerationError(error)
        }
    }

    func updateRecipeMarkdown(
        _ markdown: String,
        preservedIngredientEntries: [GeneratedIngredient] = []
    ) {
        recipeMarkdown = markdown
        guard var parsed = RecipeMarkdownRecipeParser.parse(markdown, framework: framework) else {
            onRecipeMarkdownChanged?(markdown)
            return
        }

        let preserved = GeneratedIngredient.sanitized(preservedIngredientEntries)
        let inMemory = GeneratedIngredient.sanitized(currentRecipe?.ingredientEntries ?? [])
        if !preserved.isEmpty {
            parsed.applyStructuredIngredientEntries(preserved)
        } else if !inMemory.isEmpty {
            parsed.applyStructuredIngredientEntries(inMemory)
        }

        currentRecipe = parsed
        onRecipeMarkdownChanged?(markdown)
    }

    private func setRecipeMarkdown(_ markdown: String, structuredRecipe: GeneratedRecipe? = nil) {
        recipeMarkdown = markdown
        guard var parsed = RecipeMarkdownRecipeParser.parse(markdown, framework: framework) else {
            onRecipeMarkdownChanged?(markdown)
            return
        }

        if let structuredRecipe,
           !GeneratedIngredient.sanitized(structuredRecipe.ingredientEntries).isEmpty {
            parsed.applyStructuredIngredientEntries(structuredRecipe.ingredientEntries)
        }

        currentRecipe = parsed
        onRecipeMarkdownChanged?(markdown)
    }

    private static func recipe(
        byApplying changes: [RecipeEditAppliedChange],
        to recipe: GeneratedRecipe
    ) -> GeneratedRecipe {
        changes.reduce(recipe) { partialRecipe, change in
            RecipeEditToolCallApplier.apply(change, to: partialRecipe)
        }
    }

    private func commitRecipeEdit(_ recipe: GeneratedRecipe) {
        let renderedMarkdown = RecipeMarkdownRenderer.render(
            recipe: recipe,
            framework: framework
        )

        var committedRecipe = recipe
        committedRecipe.syncIngredientsFromEntries()
        currentRecipe = committedRecipe
        setRecipeMarkdown(renderedMarkdown, structuredRecipe: committedRecipe)
        lastGeneratedMakeup = selections.ingredientMakeup
        onRecipeGenerated?(committedRecipe, renderedMarkdown)
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

        var recipeForRender = partialRecipe
        recipeForRender.syncIngredientsFromEntries()

        setRecipeMarkdown(
            RecipeMarkdownRenderer.render(
                recipe: recipeForRender,
                framework: framework
            ),
            structuredRecipe: recipeForRender
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
