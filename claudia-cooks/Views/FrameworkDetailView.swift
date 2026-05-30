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
    @State private var didConfigureSession = false

    init(
        framework: RecipeFramework,
        initialSelectedRecipeID: UUID? = nil,
        onSelectFramework: @escaping (RecipeFramework) -> Void = { _ in }
    ) {
        self.framework = framework
        self.initialSelectedRecipeID = initialSelectedRecipeID
        self.onSelectFramework = onSelectFramework

        let sessionID = UUID()
        let viewModel = RecipeBuilderViewModel(framework: framework)
        _viewModel = State(initialValue: viewModel)
        _session = State(
            initialValue: RecipeSessionController(
                sessionID: sessionID,
                framework: framework,
                livePDFData: viewModel.pdfData
            )
        )
    }

    var body: some View {
        GeometryReader { windowGeometry in
            let useCenterStage = windowGeometry.size.width > FrameworkBuildScreenLayout.centerStageBreakpoint
            let availablePreviewHeight = windowGeometry.size.height - FrameworkBuildScreenLayout.fileSystemBarHeight
            let maxPaperHeight = min(
                windowGeometry.size.height * FrameworkBuildScreenLayout.maxPaperHeightFraction,
                availablePreviewHeight * 0.92
            )

            ZStack {
                centerStageBackdrop(isActive: useCenterStage)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    buildScreen(maxPaperHeight: maxPaperHeight)
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
                        .padding(.top, useCenterStage ? FrameworkBuildScreenLayout.centerStageTopInset : 0)

                    fileSystemSection
                        .frame(height: FrameworkBuildScreenLayout.fileSystemBarHeight)
                        .zIndex(10)
                }
                .disabled(showFrameworkPicker)

                if showFrameworkPicker {
                    FrameworkPickerOverlay(
                        onSelect: selectFrameworkFromOverlay,
                        onClose: closeFrameworkPicker
                    )
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.22), value: useCenterStage)
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

    @ViewBuilder
    private func centerStageBackdrop(isActive: Bool) -> some View {
        if isActive {
            Color(nsColor: .textBackgroundColor)
        } else {
            Color(nsColor: .windowBackgroundColor)
        }
    }

    private func buildScreen(maxPaperHeight: CGFloat) -> some View {
        HoverSplitView(
            leadingWidth: $builderPanelWidth,
            trailingWidth: $previewPanelWidth,
            panelSpacing: FrameworkBuildScreenLayout.builderPaperSpacing
        ) {
            FrameworkBuilderPanel(framework: framework, viewModel: viewModel)
        } trailing: {
            previewPanel(maxPaperHeight: maxPaperHeight)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.bottom, -FrameworkBuildScreenLayout.paperOverlapIntoBar)
                .zIndex(1)
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: builderPanelWidth)
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: previewPanelWidth)
    }

    private func previewPanel(maxPaperHeight: CGFloat) -> some View {
        StackedPaperPreview(
            sheets: session.paperSheets(selections: viewModel.selections, libraryStore: libraryStore),
            selectedSheetID: session.activeSheetID,
            isGenerating: session.selectedRecipe == nil
                && !session.isBlankPage(selections: viewModel.selections, libraryStore: libraryStore)
                && viewModel.isGenerating,
            maxPaperHeight: maxPaperHeight,
            containerWidth: previewPanelWidth
        )
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var fileSystemSection: some View {
        FileSystemSection(
            recipes: libraryStore.recipes,
            selectedRecipeID: session.selectedRecipe?.id,
            pdfData: { recipe in
                session.pdfData(for: recipe, libraryStore: libraryStore)
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
            }
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

        session.ensureBlankSession(libraryStore: libraryStore)
        session.livePDFData = viewModel.pdfData

        viewModel.onPDFDataChanged = { data in
            session.livePDFData = data
        }

        viewModel.onRecipeGenerated = { recipe, pdfData in
            session.upsertGeneratedRecipe(recipe, pdfData: pdfData, libraryStore: libraryStore)
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

#Preview {
    @Previewable @State var libraryStore = RecipeLibraryStore()

    NavigationStack {
        FrameworkDetailView(framework: .bowl)
            .frame(width: 1100, height: 760)
    }
    .environment(libraryStore)
}
