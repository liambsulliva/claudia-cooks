//
//  IngredientCatalogStore.swift
//  claudia-cooks
//

import Foundation
import Observation

struct EditableIngredientCategoryCatalog: Codable, Equatable, Identifiable {
    var id: IngredientCategory
    var groups: [IngredientOptionGroup]
}

struct EditableIngredientCatalog: Codable, Equatable {
    var categories: [EditableIngredientCategoryCatalog]
    var variantsByBase: [String: [String]]

    static var defaults: EditableIngredientCatalog {
        EditableIngredientCatalog(
            categories: IngredientCategory.allCases.map { category in
                EditableIngredientCategoryCatalog(
                    id: category,
                    groups: IngredientCatalog.defaultOptionGroups(for: category)
                )
            },
            variantsByBase: IngredientVariantCatalog.defaultVariantsByBase
        )
    }

    func category(_ category: IngredientCategory) -> EditableIngredientCategoryCatalog? {
        categories.first { $0.id == category }
    }

    mutating func ensureDefaultCategoriesExist() {
        for category in IngredientCategory.allCases where self.category(category) == nil {
            categories.append(
                EditableIngredientCategoryCatalog(
                    id: category,
                    groups: IngredientCatalog.defaultOptionGroups(for: category)
                )
            )
        }

        categories.sort { lhs, rhs in
            guard let lhsIndex = IngredientCategory.allCases.firstIndex(of: lhs.id),
                  let rhsIndex = IngredientCategory.allCases.firstIndex(of: rhs.id) else {
                return lhs.id.rawValue < rhs.id.rawValue
            }

            return lhsIndex < rhsIndex
        }
    }
}

@Observable
final class IngredientCatalogStore {
    static let shared = IngredientCatalogStore()

    private static let storageKey = "claudia-cooks.ingredient-catalog.v1"

    var catalog: EditableIngredientCatalog {
        didSet {
            save()
        }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let encoder = JSONEncoder()
    @ObservationIgnored private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let decoder = JSONDecoder()
        if let data = defaults.data(forKey: Self.storageKey),
           var decoded = try? decoder.decode(EditableIngredientCatalog.self, from: data) {
            decoded.ensureDefaultCategoriesExist()
            catalog = decoded
        } else {
            catalog = .defaults
        }
    }

    func optionGroups(for category: IngredientCategory) -> [IngredientOptionGroup] {
        catalog.category(category)?.groups ?? IngredientCatalog.defaultOptionGroups(for: category)
    }

    func options(for category: IngredientCategory) -> [String] {
        optionGroups(for: category).flatMap(\.options)
    }

    func variants(for baseOption: String) -> [String]? {
        let variants = catalog.variantsByBase[baseOption, default: []]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return variants.isEmpty ? nil : variants
    }

    func addGroup(named name: String, to category: IngredientCategory) {
        let trimmedName = normalizedName(name)
        guard !trimmedName.isEmpty,
              let categoryIndex = ensureCategoryIndex(category) else {
            return
        }

        catalog.categories[categoryIndex].groups.append(
            IngredientOptionGroup(subgroup: trimmedName, options: [])
        )
    }

    func updateGroupName(
        _ name: String,
        in category: IngredientCategory,
        groupIndex: Int
    ) {
        guard let group = groupLocation(category: category, groupIndex: groupIndex) else {
            return
        }

        catalog.categories[group.categoryIndex].groups[group.groupIndex].subgroup = name
    }

    func deleteGroup(
        in category: IngredientCategory,
        groupIndex: Int
    ) {
        guard let group = groupLocation(category: category, groupIndex: groupIndex) else {
            return
        }

        let removedOptions = catalog.categories[group.categoryIndex].groups[group.groupIndex].options
        catalog.categories[group.categoryIndex].groups.remove(at: group.groupIndex)

        for option in removedOptions {
            catalog.variantsByBase.removeValue(forKey: option)
        }
    }

    func addOption(
        _ option: String,
        to category: IngredientCategory,
        groupIndex: Int
    ) {
        let trimmedOption = normalizedName(option)
        guard !trimmedOption.isEmpty,
              let group = groupLocation(category: category, groupIndex: groupIndex),
              !catalog.categories[group.categoryIndex].groups[group.groupIndex].options.contains(trimmedOption) else {
            return
        }

        catalog.categories[group.categoryIndex].groups[group.groupIndex].options.append(trimmedOption)
    }

    func updateOptionName(
        _ name: String,
        in category: IngredientCategory,
        groupIndex: Int,
        optionIndex: Int
    ) {
        guard let option = optionLocation(
            category: category,
            groupIndex: groupIndex,
            optionIndex: optionIndex
        ) else {
            return
        }

        let oldName = catalog.categories[option.categoryIndex].groups[option.groupIndex].options[option.optionIndex]
        catalog.categories[option.categoryIndex].groups[option.groupIndex].options[option.optionIndex] = name
        moveVariants(from: oldName, to: name)
    }

    func deleteOption(
        in category: IngredientCategory,
        groupIndex: Int,
        optionIndex: Int
    ) {
        guard let option = optionLocation(
            category: category,
            groupIndex: groupIndex,
            optionIndex: optionIndex
        ) else {
            return
        }

        let removedOption = catalog.categories[option.categoryIndex].groups[option.groupIndex].options.remove(at: option.optionIndex)
        catalog.variantsByBase.removeValue(forKey: removedOption)
    }

    func addVariant(_ variant: String, to baseOption: String) {
        let trimmedVariant = normalizedName(variant)
        guard !trimmedVariant.isEmpty else {
            return
        }

        var variants = catalog.variantsByBase[baseOption, default: []]
        guard !variants.contains(trimmedVariant) else {
            return
        }

        variants.append(trimmedVariant)
        catalog.variantsByBase[baseOption] = variants
    }

    func updateVariantName(
        _ name: String,
        for baseOption: String,
        variantIndex: Int
    ) {
        guard catalog.variantsByBase[baseOption]?.indices.contains(variantIndex) == true else {
            return
        }

        catalog.variantsByBase[baseOption]?[variantIndex] = name
    }

    func deleteVariant(for baseOption: String, variantIndex: Int) {
        guard catalog.variantsByBase[baseOption]?.indices.contains(variantIndex) == true else {
            return
        }

        catalog.variantsByBase[baseOption]?.remove(at: variantIndex)
        if catalog.variantsByBase[baseOption]?.isEmpty == true {
            catalog.variantsByBase.removeValue(forKey: baseOption)
        }
    }

    func resetCategory(_ category: IngredientCategory) {
        guard let categoryIndex = ensureCategoryIndex(category) else {
            return
        }

        let oldOptions = catalog.categories[categoryIndex].groups.flatMap(\.options)
        for option in oldOptions {
            catalog.variantsByBase.removeValue(forKey: option)
        }

        let defaultGroups = IngredientCatalog.defaultOptionGroups(for: category)
        catalog.categories[categoryIndex].groups = defaultGroups

        for option in defaultGroups.flatMap(\.options) {
            if let variants = IngredientVariantCatalog.defaultVariantsByBase[option] {
                catalog.variantsByBase[option] = variants
            }
        }
    }

    func resetCatalog() {
        catalog = .defaults
    }

    private func save() {
        guard let data = try? encoder.encode(catalog) else {
            return
        }

        defaults.set(data, forKey: Self.storageKey)
    }

    private func ensureCategoryIndex(_ category: IngredientCategory) -> Int? {
        if let index = catalog.categories.firstIndex(where: { $0.id == category }) {
            return index
        }

        catalog.categories.append(
            EditableIngredientCategoryCatalog(
                id: category,
                groups: IngredientCatalog.defaultOptionGroups(for: category)
            )
        )
        return catalog.categories.indices.last
    }

    private func groupLocation(
        category: IngredientCategory,
        groupIndex: Int
    ) -> (categoryIndex: Int, groupIndex: Int)? {
        guard let categoryIndex = catalog.categories.firstIndex(where: { $0.id == category }),
              catalog.categories[categoryIndex].groups.indices.contains(groupIndex) else {
            return nil
        }

        return (categoryIndex, groupIndex)
    }

    private func optionLocation(
        category: IngredientCategory,
        groupIndex: Int,
        optionIndex: Int
    ) -> (categoryIndex: Int, groupIndex: Int, optionIndex: Int)? {
        guard let group = groupLocation(category: category, groupIndex: groupIndex),
              catalog.categories[group.categoryIndex].groups[group.groupIndex].options.indices.contains(optionIndex) else {
            return nil
        }

        return (group.categoryIndex, group.groupIndex, optionIndex)
    }

    private func moveVariants(from oldName: String, to newName: String) {
        guard oldName != newName,
              let oldVariants = catalog.variantsByBase.removeValue(forKey: oldName) else {
            return
        }

        guard !normalizedName(newName).isEmpty else {
            return
        }

        var mergedVariants = catalog.variantsByBase[newName, default: []]
        for variant in oldVariants where !mergedVariants.contains(variant) {
            mergedVariants.append(variant)
        }
        catalog.variantsByBase[newName] = mergedVariants
    }

    private func normalizedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
