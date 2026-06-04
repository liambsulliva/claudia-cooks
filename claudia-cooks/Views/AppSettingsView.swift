//
//  AppSettingsView.swift
//  claudia-cooks
//

import SwiftUI

struct AppSettingsView: View {
    var body: some View {
        TabView {
            IngredientCatalogSettingsView()
                .tabItem {
                    Label("Ingredients", systemImage: "carrot.fill")
                }

            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
        }
        .frame(width: 760, height: 560)
    }
}

private struct IngredientCatalogSettingsView: View {
    @Environment(IngredientCatalogStore.self) private var ingredientCatalog
    @State private var selectedCategory: IngredientCategory? = .protein
    @State private var newGroupName = ""
    @State private var newOptionDrafts: [String: String] = [:]
    @State private var newVariantDrafts: [String: String] = [:]

    private var activeCategory: IngredientCategory {
        selectedCategory ?? .protein
    }

    private var selectedCategoryCatalog: EditableIngredientCategoryCatalog {
        ingredientCatalog.catalog.category(activeCategory)
            ?? EditableIngredientCategoryCatalog(
                id: activeCategory,
                groups: IngredientCatalog.defaultOptionGroups(for: activeCategory)
            )
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Categories")
                    .font(.headline)
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                List(IngredientCategory.allCases, selection: $selectedCategory) { category in
                    Label(category.title, systemImage: category.icon)
                        .tag(category)
                }
                .listStyle(.sidebar)
            }
            .frame(width: 200)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    categoryHeader

                    ForEach(Array(selectedCategoryCatalog.groups.enumerated()), id: \.offset) { groupIndex, group in
                        groupEditor(group, groupIndex: groupIndex)
                    }

                    addGroupRow
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var categoryHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: activeCategory.icon)
                .font(.title2.weight(.semibold))
                .foregroundStyle(activeCategory.accentColor)
                .frame(width: 42, height: 42)
                .background(activeCategory.accentColor.opacity(0.16), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                Text(activeCategory.title)
                    .font(.title3.weight(.semibold))

                Text("Edit the food groups, foods, and variants shown across the recipe builder.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Reset Category") {
                ingredientCatalog.resetCategory(activeCategory)
            }
        }
    }

    private func groupEditor(
        _ group: IngredientOptionGroup,
        groupIndex: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                TextField(
                    "Group name",
                    text: Binding(
                        get: {
                            ingredientCatalog.optionGroups(for: activeCategory)[safe: groupIndex]?.subgroup ?? group.subgroup
                        },
                        set: { newName in
                            ingredientCatalog.updateGroupName(
                                newName,
                                in: activeCategory,
                                groupIndex: groupIndex
                            )
                        }
                    )
                )
                .font(.headline)

                Button(role: .destructive) {
                    ingredientCatalog.deleteGroup(in: activeCategory, groupIndex: groupIndex)
                } label: {
                    Label("Delete Group", systemImage: "trash")
                }
                .labelStyle(.iconOnly)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(group.options.enumerated()), id: \.offset) { optionIndex, option in
                    optionEditor(
                        option: option,
                        groupIndex: groupIndex,
                        optionIndex: optionIndex
                    )
                }

                addOptionRow(groupIndex: groupIndex)
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(activeCategory.accentColor.opacity(0.2), lineWidth: 1)
        }
    }

    private func optionEditor(
        option: String,
        groupIndex: Int,
        optionIndex: Int
    ) -> some View {
        DisclosureGroup {
            variantEditor(for: option)
                .padding(.top, 8)
        } label: {
            HStack(spacing: 10) {
                TextField(
                    "Food",
                    text: Binding(
                        get: {
                            ingredientCatalog.optionGroups(for: activeCategory)[safe: groupIndex]?.options[safe: optionIndex] ?? option
                        },
                        set: { newName in
                            ingredientCatalog.updateOptionName(
                                newName,
                                in: activeCategory,
                                groupIndex: groupIndex,
                                optionIndex: optionIndex
                            )
                        }
                    )
                )

                Button(role: .destructive) {
                    ingredientCatalog.deleteOption(
                        in: activeCategory,
                        groupIndex: groupIndex,
                        optionIndex: optionIndex
                    )
                } label: {
                    Label("Delete Food", systemImage: "trash")
                }
                .labelStyle(.iconOnly)
            }
        }
        .padding(10)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func variantEditor(for option: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            let variants = ingredientCatalog.variants(for: option) ?? []

            if variants.isEmpty {
                Text("No variants yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(variants.enumerated()), id: \.offset) { variantIndex, variant in
                    HStack(spacing: 8) {
                        TextField(
                            "Variant",
                            text: Binding(
                                get: {
                                    ingredientCatalog.variants(for: option)?[safe: variantIndex] ?? variant
                                },
                                set: { newName in
                                    ingredientCatalog.updateVariantName(
                                        newName,
                                        for: option,
                                        variantIndex: variantIndex
                                    )
                                }
                            )
                        )

                        Button(role: .destructive) {
                            ingredientCatalog.deleteVariant(for: option, variantIndex: variantIndex)
                        } label: {
                            Label("Delete Variant", systemImage: "minus.circle")
                        }
                        .labelStyle(.iconOnly)
                    }
                }
            }

            addVariantRow(for: option)
        }
        .padding(.leading, 18)
    }

    private var addGroupRow: some View {
        HStack(spacing: 10) {
            TextField("New group name", text: $newGroupName)
                .onSubmit(addGroup)

            Button("Add Group", action: addGroup)
                .disabled(newGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(16)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func addOptionRow(groupIndex: Int) -> some View {
        let key = optionDraftKey(groupIndex: groupIndex)

        return HStack(spacing: 8) {
            TextField(
                "New food",
                text: Binding(
                    get: { newOptionDrafts[key, default: ""] },
                    set: { newOptionDrafts[key] = $0 }
                )
            )
            .onSubmit {
                addOption(groupIndex: groupIndex)
            }

            Button {
                addOption(groupIndex: groupIndex)
            } label: {
                Label("Add Food", systemImage: "plus.circle.fill")
            }
            .disabled(newOptionDrafts[key, default: ""].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func addVariantRow(for option: String) -> some View {
        HStack(spacing: 8) {
            TextField(
                "New variant",
                text: Binding(
                    get: { newVariantDrafts[option, default: ""] },
                    set: { newVariantDrafts[option] = $0 }
                )
            )
            .onSubmit {
                addVariant(for: option)
            }

            Button {
                addVariant(for: option)
            } label: {
                Label("Add Variant", systemImage: "plus.circle.fill")
            }
            .disabled(newVariantDrafts[option, default: ""].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func addGroup() {
        ingredientCatalog.addGroup(named: newGroupName, to: activeCategory)
        newGroupName = ""
    }

    private func addOption(groupIndex: Int) {
        let key = optionDraftKey(groupIndex: groupIndex)
        ingredientCatalog.addOption(
            newOptionDrafts[key, default: ""],
            to: activeCategory,
            groupIndex: groupIndex
        )
        newOptionDrafts[key] = ""
    }

    private func addVariant(for option: String) {
        ingredientCatalog.addVariant(newVariantDrafts[option, default: ""], to: option)
        newVariantDrafts[option] = ""
    }

    private func optionDraftKey(groupIndex: Int) -> String {
        "\(activeCategory.rawValue)-\(groupIndex)"
    }
}

private struct GeneralSettingsView: View {
    @Environment(IngredientCatalogStore.self) private var ingredientCatalog
    @State private var preferredMeasurementSystem = CookingMeasurementPreferenceStore.preferredSystem
    @State private var preferredGenerationLanguage = RecipeGenerationLanguagePreferenceStore.preferredLanguage

    var body: some View {
        Form {
            Section("Recipe Language") {
                Text("Choose the language Claudia uses for titles, ingredients, steps, and tips.")
                    .foregroundStyle(.secondary)

                Picker("Generation language", selection: $preferredGenerationLanguage) {
                    ForEach(RecipeGenerationLanguage.allCases) { language in
                        Text(language.settingsTitle).tag(language)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: preferredGenerationLanguage) { _, newValue in
                    RecipeGenerationLanguagePreferenceStore.preferredLanguage = newValue
                }
            }

            Section("Recipe Measurements") {
                Text("Choose which units Claudia uses when generating ingredient amounts and step measurements.")
                    .foregroundStyle(.secondary)

                Picker("Measurement units", selection: $preferredMeasurementSystem) {
                    Text("No preference").tag(Optional<CookingMeasurementSystem>.none)

                    ForEach(CookingMeasurementSystem.allCases) { system in
                        Text(system.settingsTitle).tag(Optional(system))
                    }
                }
                .pickerStyle(.radioGroup)
                .onChange(of: preferredMeasurementSystem) { _, newValue in
                    CookingMeasurementPreferenceStore.preferredSystem = newValue
                }

                if let preferredMeasurementSystem {
                    Text(preferredMeasurementSystem.settingsDetail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Ingredient Catalog") {
                Text("Catalog edits are saved locally and update the builder, variant menus, recipe prompts, and ingredient graph matching.")
                    .foregroundStyle(.secondary)

                Button("Reset Entire Catalog", role: .destructive) {
                    ingredientCatalog.resetCatalog()
                }
            }
        }
        .formStyle(.grouped)
        .padding(24)
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    AppSettingsView()
        .environment(IngredientCatalogStore())
}
