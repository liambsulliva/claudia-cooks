//
//  IngredientCatalog.swift
//  claudia-cooks
//

enum IngredientCatalog {
    static func options(for category: IngredientCategory) -> [String] {
        switch category {
        case .protein:
            ["Chicken", "Salmon", "Shrimp", "Tofu", "Tempeh", "Eggs", "Beef", "Pork", "Beans", "Lentils"]
        case .carbs:
            ["Rice", "Noodles", "Potatoes", "Pasta", "Bread", "Quinoa", "Farro", "Tortilla", "Couscous", "Polenta"]
        case .veg:
            ["Spinach", "Kale", "Broccoli", "Bell Pepper", "Carrots", "Mushrooms", "Tomatoes", "Cucumber", "Cabbage", "Zucchini"]
        case .cheese:
            ["Feta", "Goat Cheese", "Cheddar", "Mozzarella", "Parmesan", "Swiss", "Pepper Jack", "Blue Cheese"]
        case .aromatics:
            ["Garlic", "Ginger", "Onion", "Scallions", "Shallot", "Lemongrass", "Chiles", "Fresh Herbs"]
        case .sauces:
            ["Vinaigrette", "Tahini", "Teriyaki", "Pesto", "Salsa Verde", "Yogurt Sauce", "Miso Glaze", "Aioli", "Hot Sauce", "Peanut Sauce"]
        }
    }
}
