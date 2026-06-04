//
//  IngredientVariantCatalog.swift
//  claudia-cooks
//

import Foundation

enum IngredientVariantCatalog {
    static let defaultVariantsByBase: [String: [String]] = [
        // Protein — meat
        "Chicken": ["Breast", "Thigh", "Whole", "Ground", "Wings"],
        "Beef": ["Ground", "Steak", "Brisket", "Chuck", "Stew Meat"],
        "Pork": ["Loin", "Shoulder", "Belly (incl. Bacon)", "Chop", "Ground"],
        "Lamb": ["Chop", "Shoulder", "Leg", "Ground"],
        "Duck": ["Breast", "Leg", "Whole"],
        "Turkey": ["Breast", "Thigh", "Ground", "Whole"],
        "Salmon": ["Fillet", "Side", "Smoked", "Canned"],
        "Shrimp": ["Peeled", "Shell-on", "Large", "Frozen"],
        "Eggs": ["Large", "Medium", "Whites Only", "Yolks Only"],
        // Protein — vegan
        "Tofu": ["Firm", "Soft", "Silken", "Smoked"],
        "Beans": ["Black", "Kidney", "Cannellini", "Pinto"],
        "Lentils": ["Brown", "Green", "Red", "Black"],
        "Chickpeas": ["Canned", "Dried"],
        // Carbs
        "Rice": ["White", "Brown", "Wild", "Jasmine", "Basmati"],
        "Pasta": ["Spaghetti", "Penne", "Fusilli", "Fresh"],
        "Noodles": ["Egg", "Rice", "Udon", "Soba"],
        "Bread": ["Sourdough", "Whole Wheat", "Brioche", "Pita"],
        "Potatoes": ["Russet", "Yukon Gold", "Fingerling", "Sweet"],
        "Sweet Potato": ["Orange", "Purple", "Japanese"],
        "Quinoa": ["White", "Red", "Black", "Tri-color"],
        // Produce
        "Onion": ["Yellow", "Red", "White", "Sweet"],
        "Garlic": ["Fresh", "Roasted", "Black"],
        "Bell Pepper": ["Red", "Green", "Yellow", "Orange"],
        "Mushrooms": ["Cremini", "Shiitake", "Oyster", "Portobello"],
        "Tomatoes": ["Roma", "Cherry", "Heirloom", "Canned"],
        "Chiles": ["Jalapeño", "Serrano", "Poblano", "Thai"],
        // Dairy
        "Cheddar": ["Sharp", "Mild", "Aged", "Shredded"],
        "Mozzarella": ["Fresh", "Low-moisture", "Smoked"],
        // Fats
        "Olive Oil": ["Extra Virgin", "Regular", "Light"],
        "Butter": ["Salted", "Unsalted", "Clarified"],
        // Liquids
        "White Wine": ["Dry", "Sweet", "Cooking"],
        "Red Wine": ["Dry", "Full-bodied", "Cooking"],
    ]

    static func variants(for baseOption: String) -> [String]? {
        IngredientCatalogStore.shared.variants(for: baseOption)
    }
}

enum IngredientSelectionLabel {
    static let variantSeparator = " · "

    static func disambiguated(base: String, variant: String) -> String {
        "\(base)\(variantSeparator)\(variant)"
    }

    static func baseOption(from selection: String) -> String {
        guard let range = selection.range(of: variantSeparator) else {
            return selection
        }
        return String(selection[..<range.lowerBound])
    }

    static func variantLabel(from selection: String) -> String? {
        guard let range = selection.range(of: variantSeparator) else {
            return nil
        }
        let variant = selection[range.upperBound...].trimmingCharacters(in: .whitespaces)
        return variant.isEmpty ? nil : variant
    }
}
