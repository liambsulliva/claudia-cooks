//
//  FrameworkBuilderPanel.swift
//  claudia-cooks
//

import SwiftUI

struct FrameworkBuilderPanel: View {
    let framework: RecipeFramework
    @Bindable var viewModel: RecipeBuilderViewModel
    @Binding var openVariantMenu: (category: IngredientCategory, option: String)?
    @State private var draftPrompt = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                statusBanner

                recipePromptField

                IngredientBentoGrid(
                    categories: framework.applicableCategories,
                    selectedOptions: { category in
                        viewModel.selections.selectedOptions[category, default: []]
                    },
                    otherText: { category in
                        Binding(
                            get: { viewModel.selections.otherText[category, default: ""] },
                            set: { viewModel.setOtherText($0, for: category) }
                        )
                    },
                    openVariantMenu: $openVariantMenu,
                    onToggle: { option, category in
                        viewModel.toggle(option, in: category)
                    },
                    onToggleVariant: { base, variant, category in
                        viewModel.toggleVariant(variant, for: base, in: category)
                    }
                )
            }
            .padding(.horizontal, FrameworkBuildScreenLayout.builderPanelContentPadding)
            .padding(.top, FrameworkBuildScreenLayout.builderPanelContentPadding)
            .padding(.bottom, FrameworkBuildScreenLayout.builderPanelContentBottomPadding)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            draftPrompt = viewModel.selections.customPrompt
        }
        .onChange(of: viewModel.selections.customPrompt) { _, newValue in
            draftPrompt = newValue
        }
    }

    @ViewBuilder
    private var statusBanner: some View {
        if let message = viewModel.errorMessage ?? viewModel.mlxSetup.modelAvailability {
            VStack(alignment: .leading, spacing: 10) {
                Label(message, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if viewModel.mlxSetup.modelAvailability != nil, !viewModel.mlxSetup.showModelSetupSheet {
                    Button("Choose model size…", action: viewModel.mlxSetup.presentModelSetup)
                        .controlSize(.small)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var recipePromptField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Recipe prompt", systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Generate", action: submitRecipePrompt)
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
                    .disabled(!canSubmitRecipePrompt)
            }

            TextField(
                "Describe what you want to cook, or pick ingredients below…",
                text: $draftPrompt,
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .lineLimit(3...8)
            .onChange(of: draftPrompt) { _, newValue in
                viewModel.updateRecipePromptDraft(newValue)
            }
            .onSubmit(submitRecipePrompt)
            .onKeyPress(.return, phases: .down) { _ in
                submitRecipePrompt()
                return .handled
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
            .background(.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text("Press Return or click Generate to run the model.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var canSubmitRecipePrompt: Bool {
        !draftPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submitRecipePrompt() {
        viewModel.submitRecipePrompt(draftPrompt)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 24) {
            Image(systemName: framework.icon)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(framework.accentColor)
                .frame(width: 64, height: 64)
                .background(framework.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text(framework.title)
                    .font(.title)
                    .fontWeight(.bold)

                Text(framework.tagline)
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text("Choose ingredients on the left. Long-press an ingredient to open its type menu, then release over a type or click one to narrow it. Recipes stack on the right and rise from the file system below.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
