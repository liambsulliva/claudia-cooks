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
                centerStageBackdrop(isActive: useCenterStage)
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
                            recipeMarkdown: { libraryStore.recipeMarkdown(for: $0) }
                        )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .transition(.opacity)
                    }
                }
                .disabled(showFrameworkPicker)

                screenModePicker
                    .padding(.top, 16)
                    .padding(.trailing, 24)
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
        .navigationTitle(framework.title)
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
                .background {
                    if useCenterStage {
                        RoundedRectangle(
                            cornerRadius: FrameworkBuildScreenLayout.centerStageCornerRadius,
                            style: .continuous
                        )
                        .fill(Color(nsColor: .windowBackgroundColor))
                    }
                }
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: useCenterStage ? FrameworkBuildScreenLayout.centerStageCornerRadius : 0,
                        style: .continuous
                    )
                )
                .shadow(
                    color: useCenterStage ? .black.opacity(0.14) : .clear,
                    radius: useCenterStage ? 20 : 0,
                    x: 0,
                    y: useCenterStage ? 10 : 0
                )
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
    }

    @ViewBuilder
    private func centerStageBackdrop(isActive: Bool) -> some View {
        if isActive {
            Color(nsColor: .textBackgroundColor)
        } else {
            Color(nsColor: .windowBackgroundColor)
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
            FrameworkBuilderPanel(framework: framework, viewModel: viewModel)
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
                selections: viewModel.selections,
                libraryStore: libraryStore,
                sessionMarkdown: viewModel.recipeMarkdown
            ),
            selectedSheetID: session.activeSheetID,
            isGenerating: session.selectedRecipe == nil
                && !session.isBlankPage(selections: viewModel.selections, libraryStore: libraryStore)
                && viewModel.isGenerating,
            maxPaperHeight: maxPaperHeight,
            containerWidth: previewPanelWidth,
            onMarkdownChange: { recipeID, markdown in
                updateMarkdown(markdown, for: recipeID)
            }
        )
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var screenModePicker: some View {
        Picker("Screen mode", selection: $screenMode) {
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

            libraryStore.updateRecipeMarkdown(markdown, for: recipeID)
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
                session.isBlankSheet(
                    recipe,
                    selections: viewModel.selections,
                    libraryStore: libraryStore
                )
            },
            fileURL: { recipe in
                libraryStore.fileURL(for: recipe)
            },
            libraryFolderURL: libraryStore.libraryFolderURL,
            onSelectRecipe: { recipe in
                withAnimation(.spring(response: 0.48, dampingFraction: 0.82)) {
                    session.selectedRecipe = recipe
                }
            },
            onDeleteRecipe: { recipe in
                session.deleteRecipe(recipe, libraryStore: libraryStore)
            },
            onAddMore: {
                withAnimation(.easeInOut(duration: 0.18)) {
                    showFrameworkPicker = true
                }
            },
            allowsKeyboardNavigation: !showFrameworkPicker && !viewModel.mlxSetup.showModelSetupSheet
        )
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

        viewModel.onRecipeMarkdownChanged = { markdown in
            session.liveRecipeMarkdown = markdown
        }

        viewModel.onSelectionsChanged = { selections in
            libraryStore.updateSelections(selections, for: session.sessionID)
        }

        viewModel.onRecipeGenerated = { recipe, recipeMarkdown in
            session.upsertGeneratedRecipe(
                recipe,
                recipeMarkdown: recipeMarkdown,
                selections: viewModel.selections,
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
            framework: .bowl,
            sessionRecipeID: UUID(),
            libraryStore: libraryStore
        )
            .frame(
                width: AppWindowMetrics.builderMinimumSize.width,
                height: AppWindowMetrics.builderMinimumSize.height
            )
    }
    .environment(libraryStore)
}
