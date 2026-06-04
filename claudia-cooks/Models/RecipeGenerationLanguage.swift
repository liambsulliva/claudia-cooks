//
//  RecipeGenerationLanguage.swift
//  claudia-cooks
//

import Foundation

enum RecipeGenerationLanguage: String, CaseIterable, Codable, Identifiable, Sendable {
    case english
    case spanish
    case french
    case german
    case italian
    case portuguese
    case japanese
    case korean
    case simplifiedChinese
    case dutch

    var id: String { rawValue }

    static let `default` = RecipeGenerationLanguage.english

    var settingsTitle: String {
        switch self {
        case .english:
            "English"
        case .spanish:
            "Spanish"
        case .french:
            "French"
        case .german:
            "German"
        case .italian:
            "Italian"
        case .portuguese:
            "Portuguese"
        case .japanese:
            "Japanese"
        case .korean:
            "Korean"
        case .simplifiedChinese:
            "Chinese (Simplified)"
        case .dutch:
            "Dutch"
        }
    }

    var promptLanguageName: String {
        switch self {
        case .english:
            "English"
        case .spanish:
            "Spanish"
        case .french:
            "French"
        case .german:
            "German"
        case .italian:
            "Italian"
        case .portuguese:
            "Portuguese"
        case .japanese:
            "Japanese"
        case .korean:
            "Korean"
        case .simplifiedChinese:
            "Simplified Chinese"
        case .dutch:
            "Dutch"
        }
    }

    var systemPromptInstruction: String? {
        guard self != .english else {
            return nil
        }

        return """
        Language preference: write the recipe title, summary, steps, and tips in \(promptLanguageName).
        Keep JSON property keys in English exactly as specified.
        """
    }

    var ingredientsSystemPromptInstruction: String? {
        guard self != .english else {
            return nil
        }

        return """
        Language preference: write every ingredient object "name" and "variant" in \(promptLanguageName).
        User selections in the prompt may be in English; translate them into natural \(promptLanguageName) cooking terms (not English leftovers).
        Keep JSON property keys in English exactly as specified.
        """
    }

    var ingredientNameFieldExample: String {
        switch self {
        case .english:
            "chicken"
        case .spanish:
            "pollo"
        case .french:
            "poulet"
        case .german:
            "Hähnchen"
        case .italian:
            "pollo"
        case .portuguese:
            "frango"
        case .japanese:
            "鶏肉"
        case .korean:
            "닭고기"
        case .simplifiedChinese:
            "鸡肉"
        case .dutch:
            "kip"
        }
    }

    var ingredientVariantFieldExample: String {
        switch self {
        case .english:
            "breast"
        case .spanish:
            "pechuga"
        case .french:
            "blanc"
        case .german:
            "Brust"
        case .italian:
            "petto"
        case .portuguese:
            "peito"
        case .japanese:
            "胸肉"
        case .korean:
            "가슴살"
        case .simplifiedChinese:
            "鸡胸肉"
        case .dutch:
            "borst"
        }
    }

    func ingredientJSONExample(measurementSystem: CookingMeasurementSystem?) -> String {
        switch measurementSystem {
        case .metric:
            metricIngredientJSONExample
        case .usCustomary, .none:
            usCustomaryIngredientJSONExample
        }
    }

    private var usCustomaryIngredientJSONExample: String {
        switch self {
        case .english:
            """
            {"ingredients":[{"quantity":"2","name":"chicken","variant":"breast"},{"quantity":"2","name":"garlic","variant":"clove"},{"quantity":"1 tbsp","name":"olive oil"}]}
            """
        case .spanish:
            """
            {"ingredients":[{"quantity":"2","name":"pollo","variant":"pechuga"},{"quantity":"2","name":"ajo","variant":"diente"},{"quantity":"1 cucharada","name":"aceite de oliva"}]}
            """
        case .french:
            """
            {"ingredients":[{"quantity":"2","name":"poulet","variant":"blanc"},{"quantity":"2","name":"ail","variant":"gousse"},{"quantity":"1 c. à soupe","name":"huile d'olive"}]}
            """
        case .german:
            """
            {"ingredients":[{"quantity":"2","name":"Hähnchen","variant":"Brust"},{"quantity":"2","name":"Knoblauch","variant":"Zehe"},{"quantity":"1 EL","name":"Olivenöl"}]}
            """
        case .italian:
            """
            {"ingredients":[{"quantity":"2","name":"pollo","variant":"petto"},{"quantity":"2","name":"aglio","variant":"spicchio"},{"quantity":"1 cucchiaio","name":"olio d'oliva"}]}
            """
        case .portuguese:
            """
            {"ingredients":[{"quantity":"2","name":"frango","variant":"peito"},{"quantity":"2","name":"alho","variant":"dente"},{"quantity":"1 colher de sopa","name":"azeite"}]}
            """
        case .japanese:
            """
            {"ingredients":[{"quantity":"2","name":"鶏肉","variant":"胸肉"},{"quantity":"2","name":"にんにく","variant":"片"},{"quantity":"大さじ1","name":"オリーブオイル"}]}
            """
        case .korean:
            """
            {"ingredients":[{"quantity":"2","name":"닭고기","variant":"가슴살"},{"quantity":"2","name":"마늘","variant":"쪽"},{"quantity":"1큰술","name":"올리브 오일"}]}
            """
        case .simplifiedChinese:
            """
            {"ingredients":[{"quantity":"2","name":"鸡肉","variant":"鸡胸肉"},{"quantity":"2","name":"大蒜","variant":"瓣"},{"quantity":"1汤匙","name":"橄榄油"}]}
            """
        case .dutch:
            """
            {"ingredients":[{"quantity":"2","name":"kip","variant":"borst"},{"quantity":"2","name":"knoflook","variant":"teen"},{"quantity":"1 el","name":"olijfolie"}]}
            """
        }
    }

    private var metricIngredientJSONExample: String {
        switch self {
        case .english:
            """
            {"ingredients":[{"quantity":"400 g","name":"chicken","variant":"breast"},{"quantity":"2","name":"garlic","variant":"clove"},{"quantity":"15 ml","name":"olive oil"}]}
            """
        case .spanish:
            """
            {"ingredients":[{"quantity":"400 g","name":"pollo","variant":"pechuga"},{"quantity":"2","name":"ajo","variant":"diente"},{"quantity":"15 ml","name":"aceite de oliva"}]}
            """
        case .french:
            """
            {"ingredients":[{"quantity":"400 g","name":"poulet","variant":"blanc"},{"quantity":"2","name":"ail","variant":"gousse"},{"quantity":"15 ml","name":"huile d'olive"}]}
            """
        case .german:
            """
            {"ingredients":[{"quantity":"400 g","name":"Hähnchen","variant":"Brust"},{"quantity":"2","name":"Knoblauch","variant":"Zehe"},{"quantity":"15 ml","name":"Olivenöl"}]}
            """
        case .italian:
            """
            {"ingredients":[{"quantity":"400 g","name":"pollo","variant":"petto"},{"quantity":"2","name":"aglio","variant":"spicchio"},{"quantity":"15 ml","name":"olio d'oliva"}]}
            """
        case .portuguese:
            """
            {"ingredients":[{"quantity":"400 g","name":"frango","variant":"peito"},{"quantity":"2","name":"alho","variant":"dente"},{"quantity":"15 ml","name":"azeite"}]}
            """
        case .japanese:
            """
            {"ingredients":[{"quantity":"400 g","name":"鶏肉","variant":"胸肉"},{"quantity":"2","name":"にんにく","variant":"片"},{"quantity":"15 ml","name":"オリーブオイル"}]}
            """
        case .korean:
            """
            {"ingredients":[{"quantity":"400 g","name":"닭고기","variant":"가슴살"},{"quantity":"2","name":"마늘","variant":"쪽"},{"quantity":"15 ml","name":"올리브 오일"}]}
            """
        case .simplifiedChinese:
            """
            {"ingredients":[{"quantity":"400 g","name":"鸡肉","variant":"鸡胸肉"},{"quantity":"2","name":"大蒜","variant":"瓣"},{"quantity":"15 ml","name":"橄榄油"}]}
            """
        case .dutch:
            """
            {"ingredients":[{"quantity":"400 g","name":"kip","variant":"borst"},{"quantity":"2","name":"knoflook","variant":"teen"},{"quantity":"15 ml","name":"olijfolie"}]}
            """
        }
    }
}
