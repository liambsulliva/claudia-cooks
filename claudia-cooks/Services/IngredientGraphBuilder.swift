//
//  IngredientGraphBuilder.swift
//  claudia-cooks
//

import CoreGraphics
import Foundation

struct IngredientGraphData: Equatable {
    static let empty = IngredientGraphData()

    let nodes: [IngredientGraphNode]
    let edges: [IngredientGraphEdge]
    let recipeCount: Int
    let maxNodeOccurrences: Int
    let maxEdgeRecipeCount: Int

    fileprivate init(
        nodes: [IngredientGraphNode] = [],
        edges: [IngredientGraphEdge] = [],
        recipeCount: Int = 0,
        maxNodeOccurrences: Int = 1,
        maxEdgeRecipeCount: Int = 1
    ) {
        self.nodes = nodes
        self.edges = edges
        self.recipeCount = recipeCount
        self.maxNodeOccurrences = maxNodeOccurrences
        self.maxEdgeRecipeCount = maxEdgeRecipeCount
    }

    var visibleCategories: [IngredientCategory] {
        IngredientCategory.allCases.filter { category in
            nodes.contains { $0.category == category }
        }
    }

    var summary: String {
        "\(nodes.count) ingredients · \(edges.count) links · \(recipeCount) recipes"
    }

    var layoutKey: String {
        nodes.map { "\($0.id):\($0.occurrenceCount)" }.joined(separator: "|")
            + edges.map { "\($0.id):\($0.recipeCount)" }.joined(separator: "|")
    }

    func radius(for node: IngredientGraphNode) -> CGFloat {
        min(15 + CGFloat(node.occurrenceCount - 1) * 5, 38)
    }

    func lineWidth(for edge: IngredientGraphEdge) -> CGFloat {
        min(1.2 + CGFloat(edge.recipeCount - 1) * 1.4, 8)
    }

    /// Scales edge length and layout radii as the graph grows so connected nodes stay separated.
    func spacingMultiplier(in size: CGSize) -> CGFloat {
        guard nodes.count > 1 else {
            return 1
        }

        let count = CGFloat(nodes.count)
        let densityBoost = sqrt(count / 3)
        let canvasSide = max(min(size.width, size.height) - 110, 1)
        let canvasBoost = canvasSide / 320
        let requestedMultiplier = min(max(densityBoost, canvasBoost, 1), 3.4)
        return IngredientGraphPhysics.stableSpacingMultiplier(
            requestedMultiplier: requestedMultiplier,
            nodeCount: nodes.count,
            canvasSize: size
        )
    }

    func positions(in size: CGSize) -> [String: CGPoint] {
        guard !nodes.isEmpty else {
            return [:]
        }

        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let drawableSide = max(min(size.width, size.height) - 110, 1)
        let spacingScale = spacingMultiplier(in: size)
        let mainRadius = max(drawableSide * 0.34 * spacingScale, nodes.count == 1 ? 0 : 72 * spacingScale)
        let categories = visibleCategories

        return categories.enumerated().reduce(into: [:]) { result, categoryEntry in
            let categoryNodes = nodes
                .filter { $0.category == categoryEntry.element }
                .sorted { lhs, rhs in
                    if lhs.occurrenceCount != rhs.occurrenceCount {
                        return lhs.occurrenceCount > rhs.occurrenceCount
                    }

                    return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                }

            let categoryAngle = Self.layoutAngle(
                for: categoryEntry.offset,
                count: max(categories.count, 1)
            )
            let categoryCenter = categories.count == 1
                ? center
                : Self.layoutPoint(from: center, angle: categoryAngle, radius: mainRadius)
            let clusterRadius = min(
                max(CGFloat(categoryNodes.count) * 8 * spacingScale, 24 * spacingScale),
                max(mainRadius * 0.34, 24 * spacingScale)
            )

            for nodeEntry in categoryNodes.enumerated() {
                let node = nodeEntry.element
                let radius = radius(for: node)
                let point: CGPoint

                if categoryNodes.count == 1 {
                    point = categoryCenter
                } else {
                    let nodeAngle = categoryAngle
                        + Self.layoutAngle(
                            for: nodeEntry.offset,
                            count: categoryNodes.count,
                            startsAtTop: false
                        )
                    point = Self.layoutPoint(from: categoryCenter, angle: nodeAngle, radius: clusterRadius)
                }

                result[node.id] = IngredientGraphPhysics.clamp(point, radius: radius, in: size)
            }
        }
    }

    private static func layoutAngle(for index: Int, count: Int, startsAtTop: Bool = true) -> Double {
        guard count > 0 else {
            return 0
        }

        let offset = startsAtTop ? -Double.pi / 2 : 0
        return offset + (2 * Double.pi * Double(index) / Double(count))
    }

    private static func layoutPoint(from center: CGPoint, angle: Double, radius: CGFloat) -> CGPoint {
        CGPoint(
            x: center.x + CGFloat(cos(angle)) * radius,
            y: center.y + CGFloat(sin(angle)) * radius
        )
    }
}

enum IngredientGraphBuilder {
    @MainActor
    static func build(recipes: [SavedRecipe]) -> IngredientGraphData {
        var pendingEntries: [IngredientGraphEntry] = []

        for recipe in recipes where !recipe.isBlank {
            pendingEntries.append(contentsOf: entries(for: recipe))
        }

        pendingEntries.removeAll { entry in
            RecipeMarkdownIngredientsParser.isLikelyStepContent(entry.name)
        }

        guard !pendingEntries.isEmpty else {
            return .empty
        }

        return graphData(from: pendingEntries)
    }

    private static func graphData(from entries: [IngredientGraphEntry]) -> IngredientGraphData {
        var nodeAccumulators: [String: IngredientNodeAccumulator] = [:]
        var edgeCounts: [IngredientEdgeKey: Int] = [:]
        var recipeIDsWithIngredients = Set<UUID>()

        for entry in entries {
            let category = entry.catalogCategory ?? .aromatics

            var accumulator = nodeAccumulators[entry.nodeID] ?? IngredientNodeAccumulator(
                name: entry.name,
                category: category
            )
            accumulator.occurrenceCount += 1
            nodeAccumulators[entry.nodeID] = accumulator
        }

        let entriesByRecipe = Dictionary(grouping: entries, by: \.recipeID)

        for (recipeID, recipeEntries) in entriesByRecipe {
            let uniqueInRecipe = Set(recipeEntries.map(\.nodeID))
            guard !uniqueInRecipe.isEmpty else {
                continue
            }

            recipeIDsWithIngredients.insert(recipeID)
            let ingredientIDs = uniqueInRecipe.sorted()

            for sourceIndex in ingredientIDs.indices {
                for targetIndex in ingredientIDs.index(after: sourceIndex)..<ingredientIDs.endIndex {
                    let edgeKey = IngredientEdgeKey(ingredientIDs[sourceIndex], ingredientIDs[targetIndex])
                    edgeCounts[edgeKey, default: 0] += 1
                }
            }
        }

        let nodes = nodeAccumulators.map { id, accumulator in
            IngredientGraphNode(
                id: id,
                name: accumulator.name,
                amount: nil,
                category: accumulator.category,
                occurrenceCount: accumulator.occurrenceCount
            )
        }
        .sorted { lhs, rhs in
            if lhs.occurrenceCount != rhs.occurrenceCount {
                return lhs.occurrenceCount > rhs.occurrenceCount
            }

            if lhs.category != rhs.category {
                return lhs.category.rawValue < rhs.category.rawValue
            }

            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }

        let edges = edgeCounts.map { key, recipeCount in
            IngredientGraphEdge(
                id: "\(key.sourceID)-\(key.targetID)",
                sourceID: key.sourceID,
                targetID: key.targetID,
                recipeCount: recipeCount
            )
        }
        .sorted { lhs, rhs in
            if lhs.recipeCount != rhs.recipeCount {
                return lhs.recipeCount > rhs.recipeCount
            }

            return lhs.id < rhs.id
        }

        return IngredientGraphData(
            nodes: nodes,
            edges: edges,
            recipeCount: recipeIDsWithIngredients.count,
            maxNodeOccurrences: max(nodes.map(\.occurrenceCount).max() ?? 1, 1),
            maxEdgeRecipeCount: max(edges.map(\.recipeCount).max() ?? 1, 1)
        )
    }

    private static func entries(for recipe: SavedRecipe) -> [IngredientGraphEntry] {
        let jsonEntries = recipe.ingredientEntries.compactMap { entry(from: $0, recipeID: recipe.id) }
        if !jsonEntries.isEmpty {
            return jsonEntries
        }

        return selectionEntries(for: recipe)
    }

    private static func entry(from ingredient: GeneratedIngredient, recipeID: UUID) -> IngredientGraphEntry? {
        let name = ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            return nil
        }

        return IngredientGraphEntry(
            recipeID: recipeID,
            name: name,
            catalogCategory: RecipeMarkdownIngredientsParser.catalogCategory(for: name)
        )
    }

    private static func selectionEntries(for recipe: SavedRecipe) -> [IngredientGraphEntry] {
        let selections = RecipeSelections(stored: recipe.selections)
        var entries: [IngredientGraphEntry] = []

        for category in IngredientCategory.allCases {
            for option in selections.selectedOptions[category, default: []] {
                let base = IngredientSelectionLabel.baseOption(from: option)
                guard !base.isEmpty else {
                    continue
                }

                entries.append(
                    IngredientGraphEntry(
                        recipeID: recipe.id,
                        name: base,
                        catalogCategory: category
                    )
                )
            }

            for otherIngredient in splitOtherIngredients(selections.otherText[category, default: ""]) {
                guard !RecipeMarkdownIngredientsParser.isLikelyStepContent(otherIngredient) else {
                    continue
                }

                entries.append(
                    IngredientGraphEntry(
                        recipeID: recipe.id,
                        name: otherIngredient,
                        catalogCategory: RecipeMarkdownIngredientsParser.catalogCategory(for: otherIngredient) ?? category
                    )
                )
            }
        }

        return entries
    }

    private static func splitOtherIngredients(_ text: String) -> [String] {
        text.replacingOccurrences(of: "\n", with: ",")
            .components(separatedBy: CharacterSet(charactersIn: ",;/"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

struct IngredientGraphNode: Identifiable, Equatable {
    let id: String
    let name: String
    let amount: String?
    let category: IngredientCategory
    let occurrenceCount: Int
}

struct IngredientGraphEdge: Identifiable, Equatable {
    let id: String
    let sourceID: String
    let targetID: String
    let recipeCount: Int
}

private struct IngredientGraphEntry: Equatable {
    let recipeID: UUID
    let name: String
    let catalogCategory: IngredientCategory?

    var nodeID: String {
        IngredientLineParser.normalizedName(for: name)
    }
}

private struct IngredientNodeAccumulator: Equatable {
    var name: String
    var category: IngredientCategory
    var occurrenceCount = 0
}

private struct IngredientEdgeKey: Hashable {
    let sourceID: String
    let targetID: String

    init(_ lhs: String, _ rhs: String) {
        if lhs < rhs {
            sourceID = lhs
            targetID = rhs
        } else {
            sourceID = rhs
            targetID = lhs
        }
    }
}
