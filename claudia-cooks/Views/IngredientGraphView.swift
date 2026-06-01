//
//  IngredientGraphView.swift
//  claudia-cooks
//

import SwiftUI
import AppKit

struct IngredientGraphView: View {
    let recipes: [SavedRecipe]
    var contentRefreshKey: String = ""

    @State private var graph = IngredientGraphData.empty
    @State private var highlightedCategory: IngredientCategory?

    private var graphRefreshKey: String {
        recipes
            .map { recipe in
                let entryNames = recipe.ingredientEntries.map(\.name).joined(separator: ",")
                return "\(recipe.id.uuidString):\(entryNames)"
            }
            .joined(separator: "|")
            + "|"
            + contentRefreshKey
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            if graph.nodes.isEmpty {
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
            do {
                try await Task.sleep(for: .milliseconds(350))
            } catch {
                return
            }

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
    private func reloadGraph() {
        graph = IngredientGraphBuilder.build(recipes: recipes)
    }
}

// MARK: - Interactive canvas

private struct InteractiveIngredientGraphCanvas: View {
    let graph: IngredientGraphData
    let highlightedCategory: IngredientCategory?

    private static let minViewportScale: CGFloat = 0.45
    private static let maxViewportScale: CGFloat = 3.2

    @State private var positions: [String: CGPoint] = [:]
    @State private var velocities: [String: CGVector] = [:]
    @State private var draggingNodeID: String?
    @State private var hoveredNodeID: String?
    @State private var hoverViewportPoint: CGPoint?
    @State private var dragTarget: CGPoint?
    @State private var lastFrameDate: Date?
    @State private var viewportScale: CGFloat = 1
    @State private var viewportOffset = CGSize.zero
    @State private var panStartOffset: CGSize?

    var body: some View {
        GeometryReader { geometry in
            let canvasSize = geometry.size

            TimelineView(.animation(minimumInterval: 1 / 60)) { timeline in
                ZStack {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(backdropPanGesture())

                    graphContent(canvasSize: canvasSize)
                        .scaleEffect(viewportScale, anchor: .topLeading)
                        .offset(viewportOffset)
                }
                .coordinateSpace(name: "ingredientGraphViewport")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .overlay {
                    IngredientGraphViewportEventCatcher { factor, anchor in
                        zoomViewport(by: factor, at: anchor)
                    }
                }
                .onContinuousHover(coordinateSpace: .named("ingredientGraphViewport")) { phase in
                    switch phase {
                    case .active(let location):
                        hoverViewportPoint = location
                        updateHoveredNode(atViewportPoint: location)
                    case .ended:
                        guard draggingNodeID == nil else {
                            return
                        }
                        hoverViewportPoint = nil
                        hoveredNodeID = nil
                    }
                }
                .onAppear {
                    seedPhysics(in: canvasSize, preservingExisting: false)
                    lastFrameDate = timeline.date
                }
                .onChange(of: timeline.date) { _, date in
                    stepPhysics(at: date, canvasSize: canvasSize)
                    refreshHoveredNode()
                }
                .onChange(of: canvasSize) { _, newSize in
                    guard newSize.width > 1, newSize.height > 1 else {
                        return
                    }
                    seedPhysics(in: newSize, preservingExisting: true)
                }
                .onChange(of: graph.layoutKey) { _, _ in
                    seedPhysics(in: canvasSize, preservingExisting: true)
                    hoveredNodeID = nil
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func graphContent(canvasSize: CGSize) -> some View {
        let neighborNodeIDs = hoveredNeighborNodeIDs()

        return ZStack {
            Canvas { context, _ in
                drawEdges(in: &context)
            }
            .allowsHitTesting(false)

            ForEach(graph.nodes) { node in
                let radius = graph.radius(for: node)
                let center = positions[node.id] ?? CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                let highlight = highlight(for: node, hoveredNeighborNodeIDs: neighborNodeIDs)

                IngredientGraphNodeBubble(
                    node: node,
                    radius: radius,
                    isDragging: draggingNodeID == node.id,
                    highlight: highlight
                )
                .position(center)
                .gesture(nodeDragGesture(node: node, canvasSize: canvasSize))
                .zIndex(nodeZIndex(for: node, highlight: highlight))
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
    }

    private func focusNodeID() -> String? {
        draggingNodeID ?? hoveredNodeID
    }

    private func hoveredNeighborNodeIDs() -> Set<String> {
        guard highlightedCategory == nil, let focusNodeID = focusNodeID() else {
            return []
        }

        return graph.edges.reduce(into: Set<String>()) { result, edge in
            if edge.sourceID == focusNodeID {
                result.insert(edge.targetID)
            } else if edge.targetID == focusNodeID {
                result.insert(edge.sourceID)
            }
        }
    }

    private func highlight(
        for node: IngredientGraphNode,
        hoveredNeighborNodeIDs: Set<String>
    ) -> IngredientGraphNodeHighlight {
        if let highlightedCategory {
            return node.category == highlightedCategory ? .normal : .dimmed
        }

        guard let focusNodeID = focusNodeID() else {
            return .normal
        }

        if node.id == focusNodeID {
            return .focused
        }

        return hoveredNeighborNodeIDs.contains(node.id) ? .connected : .dimmed
    }

    private func nodeZIndex(for node: IngredientGraphNode, highlight: IngredientGraphNodeHighlight) -> Double {
        if draggingNodeID == node.id {
            return 2
        }

        if highlight == .focused {
            return 1.5
        }

        if highlight == .normal || highlight == .connected {
            return 1
        }

        return 0
    }

    private func edgeEndpoints(
        from sourceCenter: CGPoint,
        sourceRadius: CGFloat,
        to targetCenter: CGPoint,
        targetRadius: CGFloat
    ) -> (start: CGPoint, end: CGPoint)? {
        let deltaX = targetCenter.x - sourceCenter.x
        let deltaY = targetCenter.y - sourceCenter.y
        let distance = hypot(deltaX, deltaY)

        guard distance > 0.001 else {
            return nil
        }

        let unitX = deltaX / distance
        let unitY = deltaY / distance

        return (
            start: CGPoint(
                x: sourceCenter.x + unitX * sourceRadius,
                y: sourceCenter.y + unitY * sourceRadius
            ),
            end: CGPoint(
                x: targetCenter.x - unitX * targetRadius,
                y: targetCenter.y - unitY * targetRadius
            )
        )
    }

    private func drawEdges(in context: inout GraphicsContext) {
        let nodeByID = Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0.id, $0) })

        for edge in graph.edges {
            guard
                let sourceCenter = positions[edge.sourceID],
                let targetCenter = positions[edge.targetID],
                let sourceNode = nodeByID[edge.sourceID],
                let targetNode = nodeByID[edge.targetID],
                let endpoints = edgeEndpoints(
                    from: sourceCenter,
                    sourceRadius: graph.radius(for: sourceNode),
                    to: targetCenter,
                    targetRadius: graph.radius(for: targetNode)
                )
            else {
                continue
            }

            var path = Path()
            path.move(to: endpoints.start)
            path.addLine(to: endpoints.end)

            var opacity = min(0.16 + CGFloat(edge.recipeCount) * 0.08, 0.58)
            var strokeColor = Color.secondary

            if let highlightedCategory {
                let sourceEmphasized = nodeByID[edge.sourceID]?.category == highlightedCategory
                let targetEmphasized = nodeByID[edge.targetID]?.category == highlightedCategory
                opacity *= sourceEmphasized && targetEmphasized ? 1 : 0.12
            } else if let focusNodeID = focusNodeID(), let focusedNode = nodeByID[focusNodeID] {
                let isIncidentToFocusedNode = edge.sourceID == focusNodeID || edge.targetID == focusNodeID
                if isIncidentToFocusedNode {
                    strokeColor = focusedNode.category.accentColor
                    opacity = min(opacity * 1.45, 0.9)
                } else {
                    opacity *= 0.12
                }
            }

            context.stroke(
                path,
                with: .color(strokeColor.opacity(opacity)),
                lineWidth: graph.lineWidth(for: edge)
            )
        }
    }

    private func refreshHoveredNode() {
        guard let hoverViewportPoint else {
            return
        }

        updateHoveredNode(atViewportPoint: hoverViewportPoint)
    }

    private func updateHoveredNode(atViewportPoint viewportPoint: CGPoint) {
        if draggingNodeID != nil {
            return
        }

        let graphPoint = graphPoint(for: viewportPoint)
        let nextHoveredNodeID = graph.nodes.compactMap { node -> (id: String, distanceSquared: CGFloat)? in
            guard let center = positions[node.id] else {
                return nil
            }

            let radius = graph.radius(for: node)
            let deltaX = graphPoint.x - center.x
            let deltaY = graphPoint.y - center.y
            let distanceSquared = deltaX * deltaX + deltaY * deltaY

            guard distanceSquared <= radius * radius else {
                return nil
            }

            return (node.id, distanceSquared)
        }
        .min { lhs, rhs in
            lhs.distanceSquared < rhs.distanceSquared
        }?
        .id

        guard hoveredNodeID != nextHoveredNodeID else {
            return
        }

        hoveredNodeID = nextHoveredNodeID
    }

    private func nodeDragGesture(node: IngredientGraphNode, canvasSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("ingredientGraphViewport"))
            .onChanged { value in
                var transaction = Transaction()
                transaction.disablesAnimations = true

                withTransaction(transaction) {
                    let graphLocation = graphPoint(for: value.location)
                    let pinned = IngredientGraphPhysics.clamp(
                        graphLocation,
                        radius: graph.radius(for: node),
                        in: canvasSize
                    )
                    draggingNodeID = node.id
                    hoveredNodeID = node.id
                    hoverViewportPoint = value.location
                    dragTarget = pinned
                    positions[node.id] = pinned
                    velocities[node.id] = .zero
                }
            }
            .onEnded { _ in
                draggingNodeID = nil
                dragTarget = nil
                refreshHoveredNode()
            }
    }

    private func backdropPanGesture() -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named("ingredientGraphViewport"))
            .onChanged { value in
                var transaction = Transaction()
                transaction.disablesAnimations = true

                withTransaction(transaction) {
                    let startOffset = panStartOffset ?? viewportOffset
                    panStartOffset = startOffset
                    viewportOffset = CGSize(
                        width: startOffset.width + value.translation.width,
                        height: startOffset.height + value.translation.height
                    )
                }
            }
            .onEnded { _ in
                panStartOffset = nil
            }
    }

    private func graphPoint(for viewportPoint: CGPoint) -> CGPoint {
        CGPoint(
            x: (viewportPoint.x - viewportOffset.width) / viewportScale,
            y: (viewportPoint.y - viewportOffset.height) / viewportScale
        )
    }

    private func zoomViewport(by factor: CGFloat, at anchor: CGPoint) {
        let clampedFactor = min(max(factor, 0.2), 5)
        let nextScale = min(max(viewportScale * clampedFactor, Self.minViewportScale), Self.maxViewportScale)

        guard nextScale != viewportScale else {
            return
        }

        var transaction = Transaction()
        transaction.disablesAnimations = true

        withTransaction(transaction) {
            let graphAnchor = graphPoint(for: anchor)
            viewportOffset = CGSize(
                width: anchor.x - graphAnchor.x * nextScale,
                height: anchor.y - graphAnchor.y * nextScale
            )
            viewportScale = nextScale
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
                spacingMultiplier: graph.spacingMultiplier(in: canvasSize),
                deltaTime: CGFloat(deltaTime)
            )
            positions = result.positions
            velocities = result.velocities
        }
    }
}

private struct IngredientGraphViewportEventCatcher: NSViewRepresentable {
    let onZoom: (CGFloat, CGPoint) -> Void

    func makeNSView(context: Context) -> EventCaptureView {
        let view = EventCaptureView()
        view.coordinator = context.coordinator
        context.coordinator.attach(to: view)
        return view
    }

    func updateNSView(_ nsView: EventCaptureView, context: Context) {
        context.coordinator.onZoom = onZoom
        context.coordinator.attach(to: nsView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onZoom: onZoom)
    }

    static func dismantleNSView(_ nsView: EventCaptureView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class EventCaptureView: NSView {
        weak var coordinator: Coordinator?

        override var isFlipped: Bool {
            true
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }
    }

    final class Coordinator {
        var onZoom: (CGFloat, CGPoint) -> Void

        private weak var view: NSView?
        private var eventMonitor: Any?

        init(onZoom: @escaping (CGFloat, CGPoint) -> Void) {
            self.onZoom = onZoom
        }

        func attach(to view: NSView) {
            self.view = view

            guard eventMonitor == nil else {
                return
            }

            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .magnify]) { [weak self] event in
                self?.handle(event) ?? event
            }
        }

        func detach() {
            if let eventMonitor {
                NSEvent.removeMonitor(eventMonitor)
                self.eventMonitor = nil
            }
        }

        private func handle(_ event: NSEvent) -> NSEvent? {
            guard
                let view,
                event.window === view.window,
                let location = location(for: event, in: view)
            else {
                return event
            }

            switch event.type {
            case .scrollWheel:
                let rawDelta = event.scrollingDeltaY
                guard abs(rawDelta) > 0.01 else {
                    return event
                }

                let normalizedDelta = event.hasPreciseScrollingDeltas ? rawDelta : rawDelta * 12
                let rawFactor = CGFloat(pow(1.0018, Double(normalizedDelta)))
                let factor = min(max(rawFactor, 0.85), 1.15)
                onZoom(factor, location)
                return nil

            case .magnify:
                let factor = min(max(1 + event.magnification, 0.8), 1.25)
                onZoom(factor, location)
                return nil

            default:
                return event
            }
        }

        private func location(for event: NSEvent, in view: NSView) -> CGPoint? {
            let location = view.convert(event.locationInWindow, from: nil)

            guard view.bounds.contains(location) else {
                return nil
            }

            return CGPoint(x: location.x, y: location.y)
        }
    }
}

private enum IngredientGraphNodeHighlight: Equatable {
    case normal
    case focused
    case connected
    case dimmed
}

private struct IngredientGraphNodeBubble: View {
    let node: IngredientGraphNode
    let radius: CGFloat
    let isDragging: Bool
    var highlight: IngredientGraphNodeHighlight = .normal

    private var isDimmed: Bool { highlight == .dimmed }
    private var isConnected: Bool { highlight == .connected }
    private var nodeColor: Color { isConnected ? Color(nsColor: .lightGray) : node.category.accentColor }
    private var labelColor: Color { isConnected ? Color(nsColor: .lightGray) : .primary }
    private var fillTopOpacity: Double { isDimmed ? 0.08 : (isConnected ? 0.20 : 0.24) }
    private var fillBottomOpacity: Double { isDimmed ? 0.04 : (isConnected ? 0.10 : 0.10) }
    private var strokeOpacity: Double { isDimmed ? 0.22 : (isConnected ? 0.9 : 1) }
    private var countOpacity: Double { isDimmed ? 0.35 : (isConnected ? 0.9 : 1) }
    private var shadowOpacity: Double { isDimmed ? 0.06 : (isDragging ? 0.35 : (isConnected ? 0.14 : 0.18)) }

    private var edgeOcclusionColor: Color {
        Color(nsColor: .windowBackgroundColor)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(edgeOcclusionColor)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            nodeColor.opacity(fillTopOpacity),
                            nodeColor.opacity(fillBottomOpacity)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .strokeBorder(
                    nodeColor.opacity(strokeOpacity),
                    lineWidth: isDragging ? 2.5 : 2
                )

            Text("\(node.occurrenceCount)")
                .font(.caption.weight(.bold))
                .foregroundStyle(nodeColor.opacity(countOpacity))
        }
        .frame(width: radius * 2, height: radius * 2)
        .shadow(
            color: nodeColor.opacity(shadowOpacity),
            radius: isDragging ? 10 : 4,
            y: 2
        )
        .scaleEffect(isDragging ? 1.06 : (isDimmed ? 0.94 : 1))
        .overlay(alignment: .top) {
            Text(node.name)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(labelColor)
                .fixedSize(horizontal: true, vertical: false)
                .offset(y: radius * 2 + 6)
                .opacity(isDimmed ? 0.3 : 1)
        }
        .opacity(isDimmed ? 0.55 : 1)
        .saturation(isDimmed ? 0.25 : 1)
        .animation(.easeInOut(duration: 0.2), value: highlight)
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isDragging)
    }
}

#Preview {
    let chickenBowlID = UUID()
    let salmonBowlID = UUID()

    IngredientGraphView(
        recipes: [
            SavedRecipe(
                id: chickenBowlID,
                title: "Chicken Rice Bowl",
                framework: .bowls,
                createdAt: .now,
                updatedAt: .now,
                fileName: "one.md",
                isBlank: false,
                selections: StoredRecipeSelections(),
                ingredientEntries: [
                    GeneratedIngredient(quantity: "2", name: "boneless chicken breasts", variant: "breast"),
                    GeneratedIngredient(quantity: "1 cup", name: "jasmine rice"),
                    GeneratedIngredient(name: "broccoli florets"),
                    GeneratedIngredient(name: "carrots"),
                    GeneratedIngredient(quantity: "3 tbsp", name: "teriyaki sauce"),
                    GeneratedIngredient(quantity: "2", name: "garlic cloves"),
                    GeneratedIngredient(quantity: "1 tbsp", name: "olive oil")
                ]
            ),
            SavedRecipe(
                id: salmonBowlID,
                title: "Salmon Bowl",
                framework: .bowls,
                createdAt: .now,
                updatedAt: .now,
                fileName: "two.md",
                isBlank: false,
                selections: StoredRecipeSelections(),
                ingredientEntries: [
                    GeneratedIngredient(name: "salmon fillets"),
                    GeneratedIngredient(quantity: "1 cup", name: "cooked rice"),
                    GeneratedIngredient(name: "broccoli"),
                    GeneratedIngredient(name: "garlic cloves"),
                    GeneratedIngredient(name: "lemon")
                ]
            )
        ]
    )
    .frame(width: 560, height: 520)
    .padding()
}
