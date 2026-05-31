//
//  IngredientCatalog.swift
//  claudia-cooks
//

struct IngredientOptionGroup: Hashable {
    let subgroup: String
    let options: [String]
}

enum IngredientCatalog {
    static func optionGroups(for category: IngredientCategory) -> [IngredientOptionGroup] {
        switch category {
        case .protein:
            [
                IngredientOptionGroup(
                    subgroup: "Meat",
                    options: ["Chicken", "Salmon", "Shrimp", "Beef", "Pork", "Turkey", "Lamb", "Duck", "Eggs"]
                ),
                IngredientOptionGroup(
                    subgroup: "Vegan",
                    options: ["Tofu", "Tempeh", "Beans", "Lentils", "Chickpeas", "Seitan"]
                ),
            ]
        case .carbs:
            [
                IngredientOptionGroup(
                    subgroup: "Grains",
                    options: ["Rice", "Noodles", "Pasta", "Bread", "Quinoa", "Farro", "Couscous", "Polenta", "Tortilla"]
                ),
                IngredientOptionGroup(
                    subgroup: "Roots",
                    options: ["Potatoes", "Sweet Potato", "Plantain", "Cassava", "Parsnips"]
                ),
            ]
        case .produce:
            [
                IngredientOptionGroup(
                    subgroup: "Leafy",
                    options: ["Spinach", "Kale", "Arugula", "Cabbage", "Lettuce", "Chard"]
                ),
                IngredientOptionGroup(
                    subgroup: "Fruiting",
                    options: ["Broccoli", "Bell Pepper", "Tomatoes", "Zucchini", "Eggplant", "Mushrooms", "Cucumber"]
                ),
                IngredientOptionGroup(
                    subgroup: "Roots",
                    options: ["Carrots", "Beets", "Celery Root", "Turnips", "Radish"]
                ),
            ]
        case .dairy:
            [
                IngredientOptionGroup(
                    subgroup: "Hard",
                    options: ["Parmesan", "Cheddar", "Swiss", "Pecorino", "Manchego"]
                ),
                IngredientOptionGroup(
                    subgroup: "Soft",
                    options: ["Feta", "Goat Cheese", "Mozzarella", "Ricotta", "Cream Cheese", "Blue Cheese"]
                ),
            ]
        case .fats:
            [
                IngredientOptionGroup(
                    subgroup: "Oils",
                    options: ["Olive Oil", "Sesame Oil", "Avocado Oil", "Coconut Oil", "Vegetable Oil", "Grapeseed Oil"]
                ),
                IngredientOptionGroup(
                    subgroup: "Liquid/Solid Fats",
                    options: ["Butter", "Ghee", "Bacon Fat", "Lard", "Shortening", "Duck Fat"]
                ),
            ]
        case .aromatics:
            [
                IngredientOptionGroup(
                    subgroup: "Alliums",
                    options: ["Garlic", "Onion", "Shallot", "Scallions", "Leeks"]
                ),
                IngredientOptionGroup(
                    subgroup: "Aromatic Roots",
                    options: ["Ginger", "Galangal", "Lemongrass", "Turmeric Root"]
                ),
                IngredientOptionGroup(
                    subgroup: "Heat",
                    options: ["Chiles", "Jalapeño", "Fresno", "Habanero"]
                ),
            ]
        case .spices:
            [
                IngredientOptionGroup(
                    subgroup: "Spices",
                    options: ["Cumin", "Paprika", "Turmeric", "Cinnamon", "Coriander", "Black Pepper", "Nutmeg"]
                ),
                IngredientOptionGroup(
                    subgroup: "Dried Herbs",
                    options: ["Oregano", "Thyme", "Rosemary", "Bay Leaf", "Red Pepper Flakes", "Dried Basil"]
                ),
            ]
        case .acids:
            [
                IngredientOptionGroup(
                    subgroup: "Vinegar",
                    options: ["Rice Vinegar", "Apple Cider Vinegar", "Balsamic", "White Wine Vinegar", "Sherry Vinegar"]
                ),
                IngredientOptionGroup(
                    subgroup: "Citrus",
                    options: ["Lemon", "Lime", "Orange", "Yuzu", "Grapefruit"]
                ),
            ]
        case .liquids:
            [
                IngredientOptionGroup(
                    subgroup: "Broths",
                    options: ["Chicken Broth", "Vegetable Broth", "Beef Broth", "Dashi", "Coconut Milk"]
                ),
                IngredientOptionGroup(
                    subgroup: "Wines",
                    options: ["White Wine", "Red Wine", "Sherry", "Mirin", "Sake"]
                ),
                IngredientOptionGroup(
                    subgroup: "Water",
                    options: ["Water", "Stock Concentrate", "Tomato Juice"]
                ),
            ]
        case .enhancers:
            [
                IngredientOptionGroup(
                    subgroup: "Condiments",
                    options: ["Soy Sauce", "Mustard", "Hot Sauce", "Tahini", "Peanut Butter", "Tomato Paste"]
                ),
                IngredientOptionGroup(
                    subgroup: "Umami Boosters",
                    options: ["Fish Sauce", "Miso", "Worcestershire", "Anchovy Paste", "Nutritional Yeast", "Mushroom Powder"]
                ),
            ]
        }
    }

    static func options(for category: IngredientCategory) -> [String] {
        optionGroups(for: category).flatMap(\.options)
    }

    static func variants(for option: String) -> [String]? {
        IngredientVariantCatalog.variants(for: option)
    }
}
