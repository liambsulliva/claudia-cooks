//
//  CookingMeasurementSystem.swift
//  claudia-cooks
//

import Foundation

enum CookingMeasurementSystem: String, CaseIterable, Codable, Identifiable, Sendable {
    case metric
    case usCustomary

    var id: String { rawValue }

    var settingsTitle: String {
        switch self {
        case .metric:
            "Metric"
        case .usCustomary:
            "US customary"
        }
    }

    var settingsDetail: String {
        switch self {
        case .metric:
            "Grams, milliliters, and °C in generated recipes."
        case .usCustomary:
            "Cups, tablespoons, ounces, and °F in generated recipes."
        }
    }

    var systemPromptInstruction: String {
        switch self {
        case .metric:
            """
            Measurement preference: use metric units only for ingredient quantities and any amounts in steps.
            Prefer grams (g) or kilograms (kg) for weight, milliliters (ml) or liters (l) for volume, and degrees Celsius (°C) for oven temperatures.
            Do not use cups, tablespoons, teaspoons, fluid ounces, pounds, or Fahrenheit.
            """
        case .usCustomary:
            """
            Measurement preference: use US customary units only for ingredient quantities and any amounts in steps.
            Prefer cups, tablespoons (tbsp), teaspoons (tsp), fluid ounces (fl oz), ounces (oz), pounds (lb), and degrees Fahrenheit (°F) for oven temperatures.
            Do not use grams, kilograms, milliliters, liters, or Celsius.
            """
        }
    }

    var ingredientQuantityExampleHint: String {
        switch self {
        case .metric:
            "e.g. \"200 g\", \"15 ml\", \"2\""
        case .usCustomary:
            "e.g. \"2\", \"1 tbsp\", \"8 oz\""
        }
    }

    var ingredientJSONExample: String {
        switch self {
        case .metric:
            """
            {"ingredients":[{"quantity":"400 g","name":"chicken","variant":"breast"},{"quantity":"2","name":"garlic","variant":"clove"},{"quantity":"15 ml","name":"olive oil"}]}
            """
        case .usCustomary:
            """
            {"ingredients":[{"quantity":"2","name":"chicken","variant":"breast"},{"quantity":"2","name":"garlic","variant":"clove"},{"quantity":"1 tbsp","name":"olive oil"}]}
            """
        }
    }
}
