//
//  IngredientGraphView.swift
//  claudia-cooks
//

import SwiftUI

struct IngredientGraphView: View {
    let recipes: [SavedRecipe]
    var recipeMarkdown: (SavedRecipe) -> String? = { _ in nil }

    @State private var graph = IngredientGraphData.empty
    @State private var isResolvingCategories = false
    @State private var highlightedCategory: IngredientCategory?

    private var graphRefreshKey: String {
        recipes
            .map(\.id.uuidString)
            .joined(separator: "|")
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            if graph.nodes.isEmpty, !isResolvingCategories {
                emptyState
            } else if !graph.nodes.isEmpty {
                InteractiveIngredientGraphCanvas(
                    graph: graph,
                    highlightedCategory: highlightedCategory
                )
                .ignoresSafeArea()
            }

            graphHUD
                .zIndex(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: graphRefreshKey) {
            await reloadGraph()
        }
        .onChange(of: graph.layoutKey) { _, _ in
            highlightedCategory = nil
        }
    }

    private var graphHUD: some View {
        VStack(alignment: .leading, spacing: 10) {
            graphSummaryRow
                .allowsHitTesting(false)

            if !graph.nodes.isEmpty {
                legend
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private var graphSummaryRow: some View {
        HStack(spacing: 8) {
            Text(graph.summary)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if isResolvingCategories {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    private var legend: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(graph.visibleCategories) { category in
                    categoryLegendBadge(category)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func categoryLegendBadge(_ category: IngredientCategory) -> some View {
        let isSelected = highlightedCategory == category

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                highlightedCategory = isSelected ? nil : category
            }
        } label: {
            Label {
                Text(category.title)
            } icon: {
                Circle()
                    .fill(category.accentColor)
                    .frame(width: 8, height: 8)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(isSelected ? category.accentColor : .secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background {
                Capsule()
                    .fill(
                        isSelected
                            ? category.accentColor.opacity(0.22)
                            : Color.primary.opacity(0.06)
                    )
            }
            .overlay {
                Capsule()
                    .strokeBorder(
                        category.accentColor.opacity(isSelected ? 0.55 : 0),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "circle.hexagongrid")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("Generate recipes with ingredients to build the graph.")
                .font(.subheadline.weight(.semibold))

            Text("Nodes grow as ingredients appear in more saved recipes. Edges thicken when the same ingredient pair repeats across recipes.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 48)
    }

    @MainActor
    private func reloadGraph() async {
        isResolvingCategories = true
        graph = await IngredientGraphBuilder.build(
            recipes: recipes,
            recipeMarkdown: recipeMarkdown
        )
        isResolvingCategories = false
    }
}

// MARK: - Interactive canvas

private struct InteractiveIngredientGraphCanvas: View {
    let graph: IngredientGraphData
    let highlightedCategory: IngredientCategory?

    @State private var positions: [String: CGPoint] = [:]
    @State private var velocities: [String: CGVector] = [:]
    @State private var draggingNodeID: String?
    @State private var dragTarget: CGPoint?
    @State private var lastFrameDate: Date?

    var body: some View {
        GeometryReader { geometry in
            let canvasSize = geometry.size

            TimelineView(.animation(minimumInterval: 1 / 60)) { timeline in
                ZStack {
                    Canvas { context, _ in
                        drawEdges(in: &context)
                    }
                    .allowsHitTesting(false)

                    ForEach(graph.nodes) { node in
                        let radius = graph.radius(for: node)
                        let center = positions[node.id] ?? CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                        let isEmphasized = isNodeEmphasized(node)

                        IngredientGraphNodeBubble(
                            node: node,
                            radius: radius,
                            isDragging: draggingNodeID == node.id,
                            isDimmed: !isEmphasized
                        )
                        .position(center)
                        .gesture(nodeDragGesture(node: node, canvasSize: canvasSize))
                        .zIndex(nodeZIndex(for: node, isEmphasized: isEmphasized))
                    }
                }
                .coordinateSpace(name: "ingredientGraphCanvas")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    seedPhysics(in: canvasSize, preservingExisting: false)
                    lastFrameDate = timeline.date
                }
                .onChange(of: timeline.date) { _, date in
                    stepPhysics(at: date, canvasSize: canvasSize)
                }
                .onChange(of: canvasSize) { _, newSize in
                    guard newSize.width > 1, newSize.height > 1 else {
                        return
                    }
                    seedPhysics(in: newSize, preservingExisting: true)
                }
                .onChange(of: graph.layoutKey) { _, _ in
                    seedPhysics(in: canvasSize, preservingExisting: true)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func isNodeEmphasized(_ node: IngredientGraphNode) -> Bool {
        guard let highlightedCategory else {
            return true
        }

        return node.category == highlightedCategory
    }

    private func nodeZIndex(for node: IngredientGraphNode, isEmphasized: Bool) -> Double {
        if draggingNodeID == node.id {
            return 2
        }

        if highlightedCategory != nil, isEmphasized {
            return 1
        }

        return 0
    }

    private func drawEdges(in context: inout GraphicsContext) {
        let categoryByNodeID = Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0.id, $0.category) })

        for edge in graph.edges {
            guard let source = positions[edge.sourceID], let target = positions[edge.targetID] else {
                continue
            }

            var path = Path()
            path.move(to: source)
            path.addLine(to: target)

            var opacity = min(0.16 + CGFloat(edge.recipeCount) * 0.08, 0.58)

            if let highlightedCategory {
                let sourceEmphasized = categoryByNodeID[edge.sourceID] == highlightedCategory
                let targetEmphasized = categoryByNodeID[edge.targetID] == highlightedCategory
                opacity *= sourceEmphasized && targetEmphasized ? 1 : 0.12
            }

            context.stroke(
                path,
                with: .color(.secondary.opacity(opacity)),
                lineWidth: graph.lineWidth(for: edge)
            )
        }
    }

    private func nodeDragGesture(node: IngredientGraphNode, canvasSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("ingredientGraphCanvas"))
            .onChanged { value in
                var transaction = Transaction()
                transaction.disablesAnimations = true

                withTransaction(transaction) {
                    let pinned = IngredientGraphPhysics.clamp(
                        value.location,
                        radius: graph.radius(for: node),
                        in: canvasSize
                    )
                    draggingNodeID = node.id
                    dragTarget = pinned
                    positions[node.id] = pinned
                    velocities[node.id] = .zero
                }
            }
            .onEnded { _ in
                draggingNodeID = nil
                dragTarget = nil
            }
    }

    private func seedPhysics(in canvasSize: CGSize, preservingExisting: Bool) {
        let layout = graph.positions(in: canvasSize)

        if preservingExisting {
            var merged = positions
            var mergedVelocities = velocities

            for node in graph.nodes {
                if merged[node.id] == nil {
                    merged[node.id] = layout[node.id]
                }
                if mergedVelocities[node.id] == nil {
                    mergedVelocities[node.id] = .zero
                }
            }
            for staleID in merged.keys where !graph.nodes.contains(where: { $0.id == staleID }) {
                merged.removeValue(forKey: staleID)
                mergedVelocities.removeValue(forKey: staleID)
            }
            positions = merged
            velocities = mergedVelocities
        } else {
            positions = layout
            velocities = graph.nodes.reduce(into: [:]) { result, node in
                result[node.id] = .zero
            }
        }
    }

    private func stepPhysics(at date: Date, canvasSize: CGSize) {
        guard canvasSize.width > 1, canvasSize.height > 1, !positions.isEmpty else {
            lastFrameDate = date
            return
        }

        guard let lastFrameDate else {
            self.lastFrameDate = date
            return
        }

        let rawDelta = date.timeIntervalSince(lastFrameDate)
        let deltaTime = min(max(rawDelta, 1 / 120), 1 / 30)
        self.lastFrameDate = date

        var radii: [String: CGFloat] = [:]
        for node in graph.nodes {
            radii[node.id] = graph.radius(for: node)
        }

        var drag: IngredientGraphPhysics.DragTarget?
        if let draggingNodeID, let dragTarget {
            drag = IngredientGraphPhysics.DragTarget(nodeID: draggingNodeID, point: dragTarget)
        }

        var transaction = Transaction()
        transaction.disablesAnimations = true

        withTransaction(transaction) {
            let result = IngredientGraphPhysics.step(
                positions: positions,
                velocities: velocities,
                radii: radii,
                edges: graph.edges,
                dragTarget: drag,
                canvasSize: canvasSize,
                deltaTime: CGFloat(deltaTime)
            )
            positions = result.positions
            velocities = result.velocities
        }
    }
}

private struct IngredientGraphNodeBubble: View {
    let node: IngredientGraphNode
    let radius: CGFloat
    let isDragging: Bool
    var isDimmed = false

    private var fillTopOpacity: Double { isDimmed ? 0.08 : 0.24 }
    private var fillBottomOpacity: Double { isDimmed ? 0.04 : 0.10 }
    private var strokeOpacity: Double { isDimmed ? 0.22 : 1 }
    private var countOpacity: Double { isDimmed ? 0.35 : 1 }
    private var shadowOpacity: Double { isDimmed ? 0.06 : (isDragging ? 0.35 : 0.18) }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            node.category.accentColor.opacity(fillTopOpacity),
                            node.category.accentColor.opacity(fillBottomOpacity)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .strokeBorder(
                    node.category.accentColor.opacity(strokeOpacity),
                    lineWidth: isDragging ? 2.5 : 2
                )

            Text("\(node.occurrenceCount)")
                .font(.caption.weight(.bold))
                .foregroundStyle(node.category.accentColor.opacity(countOpacity))
        }
        .frame(width: radius * 2, height: radius * 2)
        .shadow(
            color: node.category.accentColor.opacity(shadowOpacity),
            radius: isDragging ? 10 : 4,
            y: 2
        )
        .scaleEffect(isDragging ? 1.06 : (isDimmed ? 0.94 : 1))
        .overlay(alignment: .top) {
            VStack(spacing: 2) {
                if let amount = node.amount {
                    Text(amount)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(node.name)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: radius * 2.8)
            .offset(y: radius * 2 + 6)
            .opacity(isDimmed ? 0.3 : 1)
        }
        .opacity(isDimmed ? 0.55 : 1)
        .saturation(isDimmed ? 0.25 : 1)
        .animation(.easeInOut(duration: 0.2), value: isDimmed)
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isDragging)
    }
}

#Preview {
    let chickenBowlID = UUID()
    let salmonBowlID = UUID()

    return IngredientGraphView(
        recipes: [
            SavedRecipe(
                id: chickenBowlID,
                title: "Chicken Rice Bowl",
                framework: .bowl,
                createdAt: .now,
                updatedAt: .now,
                fileName: "one.md",
                isBlank: false,
                selections: StoredRecipeSelections(
                    selectedOptions: [
                        "protein": ["Chicken"],
                        "carbs": ["Rice"]
                    ]
                )
            ),
            SavedRecipe(
                id: salmonBowlID,
                title: "Salmon Bowl",
                framework: .bowl,
                createdAt: .now,
                updatedAt: .now,
                fileName: "two.md",
                isBlank: false,
                selections: StoredRecipeSelections(
                    selectedOptions: [
                        "protein": ["Salmon"],
                        "carbs": ["Rice"]
                    ]
                )
            )
        ],
        recipeMarkdown: { recipe in
            switch recipe.id {
            case chickenBowlID:
                """
                ## Ingredients

                - 2 boneless chicken breasts
                - 1 cup jasmine rice
                - 2 cups broccoli florets
                - 2 carrots, sliced
                - 3 tbsp teriyaki sauce
                - 2 cloves garlic, minced
                - 1 tbsp olive oil
                """
            case salmonBowlID:
                """
                ## Ingredients

                - 2 salmon fillets
                - 1 cup cooked rice
                - 1 head broccoli, chopped
                - 3 cloves garlic
                - 1 lemon
                """
            default:
                nil
            }
        }
    )
    .frame(width: 560, height: 520)
    .padding()
}
