//
//  FrameworkDetailView.swift
//  claudia-cooks
//

import SwiftUI

struct FrameworkDetailView: View {
    let framework: RecipeFramework
    let initialSelectedRecipeID: UUID?
    let onSelectFramework: (RecipeFramework) -> Void

    @Environment(RecipeLibraryStore.self) private var libraryStore
    @State private var viewModel: RecipeBuilderViewModel
    @State private var session: RecipeSessionController
    @State private var showFrameworkPicker = false
    @State private var builderPanelWidth = FrameworkBuildScreenLayout.defaultBuilderPanelWidth
    @State private var previewPanelWidth = FrameworkBuildScreenLayout.defaultPreviewPanelWidth
    @State private var screenMode: FrameworkDetailScreenMode = .editor
    @State private var openVariantMenu: (category: IngredientCategory, option: String)?
    @State private var didConfigureSession = false
    @State private var markdownSaveTask: Task<Void, Never>?

    init(
        framework: RecipeFramework,
        sessionRecipeID: UUID,
        libraryStore: RecipeLibraryStore,
        initialSelectedRecipeID: UUID? = nil,
        onSelectFramework: @escaping (RecipeFramework) -> Void = { _ in }
    ) {
        self.framework = framework
        self.initialSelectedRecipeID = initialSelectedRecipeID
        self.onSelectFramework = onSelectFramework

        let savedRecipe = libraryStore.recipe(for: sessionRecipeID)
        let initialSelections = RecipeSelections(stored: savedRecipe?.selections ?? StoredRecipeSelections())
        let hadPersistedGeneratedRecipe = savedRecipe.map { !$0.isBlank && !$0.fileName.isEmpty } ?? false
        let initialMarkdown = savedRecipe.flatMap { libraryStore.recipeMarkdown(for: $0) }

        let viewModel = RecipeBuilderViewModel(
            framework: framework,
            initialSelections: initialSelections,
            initialMarkdown: initialMarkdown,
            hadPersistedGeneratedRecipe: hadPersistedGeneratedRecipe
        )
        _viewModel = State(initialValue: viewModel)
        _session = State(
            initialValue: RecipeSessionController(
                sessionID: sessionRecipeID,
                framework: framework,
                liveRecipeMarkdown: viewModel.recipeMarkdown
            )
        )
    }

    var body: some View {
        GeometryReader { windowGeometry in
            let useCenterStage = windowGeometry.size.width > FrameworkBuildScreenLayout.centerStageBreakpoint
            let availablePreviewHeight = windowGeometry.size.height - FrameworkBuildScreenLayout.fileSystemBarHeight
            let maxPaperHeight = max(
                min(
                    windowGeometry.size.height * FrameworkBuildScreenLayout.maxPaperHeightFraction,
                    availablePreviewHeight
                        - FrameworkBuildScreenLayout.paperStackTopInset
                        - FrameworkBuildScreenLayout.paperOverlapIntoBar
                ),
                180
            )

            ZStack(alignment: .topTrailing) {
                Color(nsColor: .windowBackgroundColor)
                    .ignoresSafeArea()

                Group {
                    switch screenMode {
                    case .editor:
                        editorScreen(
                            maxPaperHeight: maxPaperHeight,
                            availablePreviewHeight: availablePreviewHeight,
                            useCenterStage: useCenterStage
                        )
                        .transition(.opacity)

                    case .graph:
                        IngredientGraphView(
                            recipes: libraryStore.recipes,
                            contentRefreshKey: viewModel.recipeMarkdown
                        )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .transition(.opacity)
                    }
                }
                .disabled(showFrameworkPicker)

                screenModePicker
                    .padding(.top, 12)
                    .zIndex(20)

                if showFrameworkPicker {
                    FrameworkPickerOverlay(
                        onSelect: selectFrameworkFromOverlay,
                        onClose: closeFrameworkPicker
                    )
                    .transition(.opacity)
                    .zIndex(30)
                }
            }
            .animation(.easeInOut(duration: 0.22), value: useCenterStage)
            .animation(.easeInOut(duration: 0.2), value: screenMode)
        }
        .navigationTitle(activeFramework.title)
        .sheet(isPresented: $viewModel.mlxSetup.showModelSetupSheet) {
            MLXModelSetupSheet(
                selectedTier: $viewModel.mlxSetup.modelSetupTier,
                isDownloading: viewModel.mlxSetup.isPullingModel,
                downloadProgress: viewModel.mlxSetup.modelPullProgress,
                downloadError: viewModel.mlxSetup.modelPullError,
                onDownload: viewModel.mlxSetup.downloadSelectedModel,
                onCancel: viewModel.mlxSetup.cancelModelSetup
            )
        }
        .interactiveDismissDisabled(viewModel.mlxSetup.isPullingModel)
        .onAppear(perform: configureSession)
        .onChange(of: libraryStore.recipes) { _, _ in
            reconcileWithLibraryOnDisk()
        }
    }

    private func editorScreen(
        maxPaperHeight: CGFloat,
        availablePreviewHeight: CGFloat,
        useCenterStage: Bool
    ) -> some View {
        VStack(spacing: 0) {
            buildScreen(
                maxPaperHeight: maxPaperHeight,
                availablePaperHeight: availablePreviewHeight
            )
                .frame(maxWidth: useCenterStage ? FrameworkBuildScreenLayout.centerStageMaxWidth : .infinity)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, useCenterStage ? FrameworkBuildScreenLayout.centerStageHorizontalInset : 0)
                .padding(
                    .top,
                    FrameworkBuildScreenLayout.editorContentTopInset
                        + (useCenterStage ? FrameworkBuildScreenLayout.centerStageTopInset : 0)
                )

            fileSystemSection
                .frame(height: FrameworkBuildScreenLayout.fileSystemBarHeight)
                .zIndex(10)
        }
        .ingredientVariantMenuHost(
            selectionState: { option, category in
                viewModel.selections.selectionState(for: option, in: category)
            },
            onToggleVariant: { base, variant, category in
                viewModel.toggleVariant(variant, for: base, in: category)
            },
            onDismiss: { openVariantMenu = nil }
        )
        .onChange(of: session.activeSheetID) { _, _ in
            openVariantMenu = nil
        }
        .onChange(of: screenMode) { _, _ in
            openVariantMenu = nil
        }
    }

    private func buildScreen(maxPaperHeight: CGFloat, availablePaperHeight: CGFloat) -> some View {
        let sheetCount = libraryStore.recipes.count

        return HoverSplitView(
            leadingWidth: $builderPanelWidth,
            trailingWidth: $previewPanelWidth,
            panelSpacing: FrameworkBuildScreenLayout.builderPaperSpacing,
            minLeadingWidth: FrameworkBuildScreenLayout.minBuilderPanelWidth,
            maxLeadingWidth: FrameworkBuildScreenLayout.maxBuilderPanelWidth,
            minTrailingWidth: FrameworkBuildScreenLayout.minPreviewPanelWidth,
            strategicLeadingWidth: { totalWidth, totalHeight in
                FrameworkBuildScreenLayout.strategicLeadingWidth(
                    totalWidth: totalWidth,
                    availablePaperHeight: totalHeight,
                    maxPaperHeight: maxPaperHeight,
                    sheetCount: sheetCount
                )
            },
            strategicLayoutDependency: sheetCount
        ) {
            FrameworkBuilderPanel(
                framework: activeFramework,
                viewModel: viewModel,
                openVariantMenu: $openVariantMenu
            )
        } trailing: {
            previewPanel(maxPaperHeight: maxPaperHeight)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, FrameworkBuildScreenLayout.paperStackTrailingMargin)
                .padding(.bottom, -FrameworkBuildScreenLayout.paperOverlapIntoBar)
                .zIndex(1)
        }
    }

    private func previewPanel(maxPaperHeight: CGFloat) -> some View {
        StackedPaperPreview(
            sheets: session.paperSheets(
                libraryStore: libraryStore,
                sessionMarkdown: viewModel.recipeMarkdown
            ),
            selectedSheetID: session.activeSheetID,
            isGenerating: session.selectedRecipe == nil && viewModel.isGenerating,
            maxPaperHeight: maxPaperHeight,
            pendingDiff: viewModel.pendingRecipeEdit,
            containerWidth: previewPanelWidth,
            onMarkdownChange: { recipeID, markdown in
                updateMarkdown(markdown, for: recipeID)
            },
            onAcceptPendingChange: { changeID in
                viewModel.acceptPendingRecipeEditChange(changeID)
            },
            onDenyPendingChange: { changeID in
                viewModel.denyPendingRecipeEditChange(changeID)
            },
            onPendingDiffMarkdownChange: { update in
                viewModel.updateRecipeDuringPendingEdit(update)
            },
            recipeEditUndoManager: viewModel.recipeEditUndoManagerForPreview,
            recipeEditReviewUndoRevision: viewModel.recipeEditReviewUndoRevision,
            onAcceptAllPendingChanges: {
                viewModel.acceptAllPendingRecipeEditChanges()
            }
        )
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var screenModePicker: some View {
        Picker(selection: $screenMode, label: EmptyView()) {
            ForEach(FrameworkDetailScreenMode.allCases) { mode in
                Label(mode.title, systemImage: mode.icon)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 270)
    }

    private func updateMarkdown(_ markdown: String, for recipeID: UUID) {
        if recipeID == session.sessionID {
            viewModel.updateRecipeMarkdown(markdown)
            session.liveRecipeMarkdown = markdown
        }

        markdownSaveTask?.cancel()
        markdownSaveTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(350))
            } catch {
                return
            }

            let libraryEntries = libraryStore.recipe(for: recipeID)?.ingredientEntries ?? []
            let liveEntries = recipeID == session.sessionID
                ? (viewModel.currentRecipe?.ingredientEntries ?? [])
                : []
            let structuredEntries = !GeneratedIngredient.sanitized(liveEntries).isEmpty
                ? liveEntries
                : libraryEntries
            libraryStore.updateRecipeMarkdown(
                markdown,
                for: recipeID,
                ingredientEntries: structuredEntries
            )
        }
    }

    private var fileSystemSection: some View {
        FileSystemSection(
            recipes: libraryStore.recipes,
            selectedRecipeID: session.selectedRecipe?.id,
            recipeMarkdown: { recipe in
                session.recipeMarkdown(for: recipe, libraryStore: libraryStore)
            },
            isBlank: { recipe in
                session.isBlankSheet(recipe, libraryStore: libraryStore)
            },
            fileURL: { recipe in
                libraryStore.fileURL(for: recipe)
            },
            libraryFolderURL: libraryStore.libraryFolderURL,
            onSelectRecipe: selectRecipe,
            onDeleteRecipe: { recipe in
                let affectedCurrentRecipe = recipe.id == editingRecipeID
                libraryStore.updateSelections(viewModel.selections, for: editingRecipeID)
                session.deleteRecipe(recipe, libraryStore: libraryStore)
                handleRecipeDeleted(affectedCurrentRecipe: affectedCurrentRecipe)
            },
            onAddMore: {
                withAnimation(.easeInOut(duration: 0.18)) {
                    showFrameworkPicker = true
                }
            },
            allowsKeyboardNavigation: !showFrameworkPicker && !viewModel.mlxSetup.showModelSetupSheet
        )
    }

    private var editingRecipeID: UUID {
        session.selectedRecipe?.id ?? session.sessionID
    }

    private var activeFramework: RecipeFramework {
        libraryStore.recipe(for: editingRecipeID)?.framework ?? framework
    }

    private func reconcileWithLibraryOnDisk() {
        guard let selectedID = session.selectedRecipe?.id else {
            return
        }

        guard let updatedRecipe = libraryStore.recipe(for: selectedID) else {
            session.selectedRecipe = nil
            handleRecipeDeleted(affectedCurrentRecipe: true)
            return
        }

        let diskSelections = RecipeSelections(stored: updatedRecipe.selections)
        let selectionsChanged = diskSelections != viewModel.selections
        session.selectedRecipe = updatedRecipe

        if selectionsChanged {
            applyBuilderState(for: updatedRecipe)
            return
        }

        guard updatedRecipe.id == session.sessionID,
              let markdown = libraryStore.recipeMarkdown(for: updatedRecipe),
              !markdown.isEmpty,
              viewModel.recipeMarkdown != markdown else {
            return
        }

        viewModel.updateRecipeMarkdown(markdown)
        session.liveRecipeMarkdown = markdown
    }

    private func handleRecipeDeleted(affectedCurrentRecipe: Bool) {
        guard affectedCurrentRecipe else {
            return
        }

        if libraryStore.recipes.isEmpty {
            resetBuilderToEmptyState()
            return
        }

        if let sessionRecipe = libraryStore.recipe(for: session.sessionID) {
            applyBuilderState(for: sessionRecipe)
            return
        }

        if let nextRecipe = libraryStore.recipes.first {
            selectRecipe(nextRecipe)
        }
    }

    private func resetBuilderToEmptyState() {
        session.selectedRecipe = nil
        session.liveRecipeMarkdown = ""
        viewModel.loadRecipeState(
            selections: RecipeSelections(),
            hadPersistedGeneratedRecipe: false
        )
    }

    private func selectRecipe(_ recipe: SavedRecipe) {
        let isNewSelection = session.selectedRecipe?.id != recipe.id

        if isNewSelection {
            libraryStore.updateSelections(viewModel.selections, for: editingRecipeID)
        }

        withAnimation(.spring(response: 0.48, dampingFraction: 0.82)) {
            session.selectedRecipe = recipe
        }

        if isNewSelection {
            applyBuilderState(for: recipe)
        }
    }

    private func applyBuilderState(for recipe: SavedRecipe) {
        let hadPersistedGeneratedRecipe = !recipe.isBlank && !recipe.fileName.isEmpty

        viewModel.loadRecipeState(
            selections: RecipeSelections(stored: recipe.selections),
            hadPersistedGeneratedRecipe: hadPersistedGeneratedRecipe
        )

        if let markdown = libraryStore.recipeMarkdown(for: recipe), !markdown.isEmpty {
            viewModel.updateRecipeMarkdown(
                markdown,
                preservedIngredientEntries: recipe.ingredientEntries
            )

            if recipe.id == session.sessionID {
                session.liveRecipeMarkdown = markdown
            }
        }
    }

    private func configureSession() {
        guard !didConfigureSession else {
            return
        }
        didConfigureSession = true

        if session.selectedRecipe == nil,
           let initialSelectedRecipeID,
           let recipe = libraryStore.recipe(for: initialSelectedRecipeID) {
            session.selectedRecipe = recipe
        }

        session.ensureBlankSession(
            libraryStore: libraryStore,
            selections: viewModel.selections
        )
        session.liveRecipeMarkdown = viewModel.recipeMarkdown

        if let selectedRecipe = session.selectedRecipe {
            applyBuilderState(for: selectedRecipe)
        }

        viewModel.onRecipeMarkdownChanged = { markdown in
            guard editingRecipeID == session.sessionID else {
                return
            }

            session.liveRecipeMarkdown = markdown
        }

        viewModel.onSelectionsChanged = { selections in
            libraryStore.updateSelections(selections, for: editingRecipeID)
        }

        viewModel.onRecipeDocumentCleared = {
            let recipeID = session.selectedRecipe?.id ?? session.sessionID
            libraryStore.clearRecipeDocument(for: recipeID)
            if recipeID == session.sessionID {
                session.liveRecipeMarkdown = ""
            }
        }

        viewModel.onRecipeGenerated = { recipe, recipeMarkdown in
            session.upsertGeneratedRecipe(
                recipe,
                recipeMarkdown: recipeMarkdown,
                selections: viewModel.selections,
                recipeID: editingRecipeID,
                framework: activeFramework,
                libraryStore: libraryStore
            )
        }
    }

    private func selectFrameworkFromOverlay(_ selectedFramework: RecipeFramework) {
        closeFrameworkPicker()
        onSelectFramework(selectedFramework)
    }

    private func closeFrameworkPicker() {
        withAnimation(.easeInOut(duration: 0.18)) {
            showFrameworkPicker = false
        }
    }
}

private enum FrameworkDetailScreenMode: String, CaseIterable, Identifiable {
    case editor
    case graph

    var id: String { rawValue }

    var title: String {
        switch self {
        case .editor: "Editor View"
        case .graph: "Graph View"
        }
    }

    var icon: String {
        switch self {
        case .editor: "doc.richtext"
        case .graph: "point.3.connected.trianglepath.dotted"
        }
    }
}

#Preview {
    @Previewable @State var libraryStore = RecipeLibraryStore()

    NavigationStack {
        FrameworkDetailView(
            framework: .bowls,
            sessionRecipeID: UUID(),
            libraryStore: libraryStore
        )
            .frame(
                width: AppWindowMetrics.builderMinimumSize.width,
                height: AppWindowMetrics.builderMinimumSize.height
            )
    }
    .environment(libraryStore)
    .environment(IngredientCatalogStore())
}
