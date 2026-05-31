//
//  IngredientGraphPhysics.swift
//  claudia-cooks
//

import CoreGraphics

enum IngredientGraphPhysics {
    struct DragTarget {
        let nodeID: String
        let point: CGPoint
    }

    private static let collisionPadding: CGFloat = 12
    private static let edgeRestLength: CGFloat = 152
    private static let edgeStretchLimit: CGFloat = 115
    private static let edgeSpring: CGFloat = 18
    private static let edgeSnapSpring: CGFloat = 76
    private static let edgeDamping: CGFloat = 5.2
    private static let collisionSpring: CGFloat = 420
    private static let airDrag: CGFloat = 4.8
    private static let velocityLimit: CGFloat = 1_400
    private static let wallRestitution: CGFloat = 0.08
    private static let collisionCorrectionVelocityDamping: CGFloat = 0.35
    private static let collisionPositionCorrectionStrength: CGFloat = 0.55
    private static let maxCollisionCorrectionPerIteration: CGFloat = 16
    /// Per-frame velocity retention at 60 fps (~0.97 ≈ noticeable drag, settles within ~1–2 s).
    private static let frameDamping: CGFloat = 0.972

    static func step(
        positions: [String: CGPoint],
        velocities: [String: CGVector],
        radii: [String: CGFloat],
        edges: [IngredientGraphEdge],
        dragTarget: DragTarget?,
        canvasSize: CGSize,
        spacingMultiplier: CGFloat = 1,
        deltaTime: CGFloat
    ) -> (positions: [String: CGPoint], velocities: [String: CGVector]) {
        var nextPositions = positions
        var nextVelocities = velocities
        let pinnedNodeID = dragTarget?.nodeID
        var simulationPositions = positions
        let nodeCount = positions.count
        let simulationSpacingMultiplier = stableSpacingMultiplier(
            requestedMultiplier: spacingMultiplier,
            nodeCount: nodeCount,
            canvasSize: canvasSize
        )
        let mobilities = nodeMobilities(positions: positions, radii: radii, edges: edges)

        if let dragTarget {
            let radius = radii[dragTarget.nodeID, default: 16]
            let pinnedPoint = clamp(dragTarget.point, radius: radius, in: canvasSize)
            simulationPositions[dragTarget.nodeID] = pinnedPoint
            nextPositions[dragTarget.nodeID] = pinnedPoint
            nextVelocities[dragTarget.nodeID] = .zero
        }

        var forces = positions.keys.reduce(into: [String: CGVector]()) { result, nodeID in
            result[nodeID] = .zero
        }

        applyEdgeSprings(
            edges: edges,
            positions: simulationPositions,
            velocities: velocities,
            spacingMultiplier: simulationSpacingMultiplier,
            forces: &forces
        )
        let collisionForceScale = nodeCount > 24 ? CGFloat(24) / CGFloat(nodeCount) : 1

        applyCollisionForces(
            positions: simulationPositions,
            radii: radii,
            spacingMultiplier: simulationSpacingMultiplier,
            forceScale: collisionForceScale,
            forces: &forces
        )
        applyAirDrag(velocities: velocities, pinnedNodeID: pinnedNodeID, forces: &forces)

        for nodeID in positions.keys {
            if nodeID == pinnedNodeID {
                continue
            }

            guard let position = nextPositions[nodeID] else {
                continue
            }

            var velocity = nextVelocities[nodeID, default: .zero]
            let force = forces[nodeID, default: .zero]
            let mobility = mobilities[nodeID, default: 1]

            velocity.dx += force.dx * mobility * deltaTime
            velocity.dy += force.dy * mobility * deltaTime
            velocity = velocity.limited(to: velocityLimit)

            let damping = pow(frameDamping, deltaTime * 60)
            velocity.dx *= damping
            velocity.dy *= damping

            if velocity.length < 2 {
                velocity = .zero
            }

            var updatedPosition = CGPoint(
                x: position.x + velocity.dx * deltaTime,
                y: position.y + velocity.dy * deltaTime
            )

            let bounded = constrain(
                updatedPosition,
                velocity: velocity,
                radius: radii[nodeID, default: 16],
                in: canvasSize
            )
            updatedPosition = bounded.point
            velocity = bounded.velocity

            nextPositions[nodeID] = updatedPosition
            nextVelocities[nodeID] = velocity
        }

        let collisionIterations = min(8, max(2, nodeCount / 6))

        let separated = resolveCollisionPenetration(
            positions: nextPositions,
            radii: radii,
            pinnedNodeID: pinnedNodeID,
            canvasSize: canvasSize,
            spacingMultiplier: simulationSpacingMultiplier,
            mobilities: mobilities,
            iterations: collisionIterations
        )

        for (nodeID, point) in separated {
            if let currentPoint = nextPositions[nodeID],
               currentPoint.distance(to: point) > 0.25 {
                var velocity = nextVelocities[nodeID, default: .zero]
                velocity.dx *= Self.collisionCorrectionVelocityDamping
                velocity.dy *= Self.collisionCorrectionVelocityDamping
                nextVelocities[nodeID] = velocity
            }
            nextPositions[nodeID] = point
        }

        if let dragTarget {
            let radius = radii[dragTarget.nodeID, default: 16]
            nextPositions[dragTarget.nodeID] = clamp(dragTarget.point, radius: radius, in: canvasSize)
            nextVelocities[dragTarget.nodeID] = .zero
        }

        return (nextPositions, nextVelocities)
    }

    static func stableSpacingMultiplier(
        requestedMultiplier: CGFloat,
        nodeCount: Int,
        canvasSize: CGSize
    ) -> CGFloat {
        guard nodeCount > 1 else {
            return requestedMultiplier
        }

        let drawableSide = max(min(canvasSize.width, canvasSize.height) - 110, 1)
        let spreadSide = sqrt(CGFloat(nodeCount)) * edgeRestLength * 0.62
        let maxStable = drawableSide / max(spreadSide, 1)
        // Keep a generous minimum rest length; only cap runaway multipliers on dense graphs.
        let cap = max(1.35, min(maxStable * 1.2, 2.6))
        return min(requestedMultiplier, cap)
    }

    private static func nodeMobilities(
        positions: [String: CGPoint],
        radii: [String: CGFloat],
        edges: [IngredientGraphEdge]
    ) -> [String: CGFloat] {
        var edgeDegrees = positions.keys.reduce(into: [String: Int]()) { result, nodeID in
            result[nodeID] = 0
        }

        for edge in edges {
            edgeDegrees[edge.sourceID, default: 0] += 1
            edgeDegrees[edge.targetID, default: 0] += 1
        }

        return positions.keys.reduce(into: [String: CGFloat]()) { result, nodeID in
            let radiusScale = max(radii[nodeID, default: 16] / 16, 1)
            let degreeScale = 1 + min(CGFloat(edgeDegrees[nodeID, default: 0]), 12) * 0.06
            result[nodeID] = 1 / (radiusScale * degreeScale)
        }
    }

    private static func applyEdgeSprings(
        edges: [IngredientGraphEdge],
        positions: [String: CGPoint],
        velocities: [String: CGVector],
        spacingMultiplier: CGFloat,
        forces: inout [String: CGVector]
    ) {
        let scaledRestLength = edgeRestLength * spacingMultiplier
        let scaledStretchLimit = edgeStretchLimit * spacingMultiplier

        for edge in edges {
            guard
                let source = positions[edge.sourceID],
                let target = positions[edge.targetID]
            else {
                continue
            }

            let delta = CGVector(dx: target.x - source.x, dy: target.y - source.y)
            let distance = max(delta.length, 0.001)
            let normal = CGVector(dx: delta.dx / distance, dy: delta.dy / distance)
            let restLength = scaledRestLength + CGFloat(edge.recipeCount - 1) * 10 * spacingMultiplier
            let stretch = distance - restLength
            let overLimit = max(abs(stretch) - scaledStretchLimit, 0)
            let snapDirection: CGFloat = stretch >= 0 ? 1 : -1

            let sourceVelocity = velocities[edge.sourceID, default: .zero]
            let targetVelocity = velocities[edge.targetID, default: .zero]
            let relativeVelocity = CGVector(
                dx: targetVelocity.dx - sourceVelocity.dx,
                dy: targetVelocity.dy - sourceVelocity.dy
            )
            let velocityAlongSpring = relativeVelocity.dot(normal)
            let springForce = stretch * edgeSpring
                + overLimit * edgeSnapSpring * snapDirection
                + velocityAlongSpring * edgeDamping

            let force = CGVector(
                dx: normal.dx * springForce,
                dy: normal.dy * springForce
            )

            forces[edge.sourceID, default: .zero] += force
            forces[edge.targetID, default: .zero] -= force
        }
    }

    private static func applyCollisionForces(
        positions: [String: CGPoint],
        radii: [String: CGFloat],
        spacingMultiplier: CGFloat,
        forceScale: CGFloat = 1,
        forces: inout [String: CGVector]
    ) {
        let nodeIDs = positions.keys.sorted()
        let padding = collisionPadding * spacingMultiplier

        for index in nodeIDs.indices {
            let leftID = nodeIDs[index]

            for rightIndex in nodeIDs.index(after: index)..<nodeIDs.endIndex {
                let rightID = nodeIDs[rightIndex]
                guard let left = positions[leftID], let right = positions[rightID] else {
                    continue
                }

                let minimumDistance = radii[leftID, default: 16] + radii[rightID, default: 16] + padding
                var delta = CGVector(dx: right.x - left.x, dy: right.y - left.y)
                var distance = delta.length

                if distance < 0.001 {
                    let angle = Double(index + rightIndex) * 0.9
                    delta = CGVector(dx: CGFloat(cos(angle)), dy: CGFloat(sin(angle)))
                    distance = 1
                }

                guard distance < minimumDistance else {
                    continue
                }

                let normal = CGVector(dx: delta.dx / distance, dy: delta.dy / distance)
                let overlap = minimumDistance - distance
                let force = CGVector(
                    dx: normal.dx * overlap * collisionSpring * forceScale,
                    dy: normal.dy * overlap * collisionSpring * forceScale
                )

                forces[leftID, default: .zero] -= force
                forces[rightID, default: .zero] += force
            }
        }
    }

    private static func applyAirDrag(
        velocities: [String: CGVector],
        pinnedNodeID: String?,
        forces: inout [String: CGVector]
    ) {
        for (nodeID, velocity) in velocities where nodeID != pinnedNodeID {
            forces[nodeID, default: .zero] -= CGVector(
                dx: velocity.dx * airDrag,
                dy: velocity.dy * airDrag
            )
        }
    }

    private static func constrain(
        _ point: CGPoint,
        velocity: CGVector,
        radius: CGFloat,
        in size: CGSize
    ) -> (point: CGPoint, velocity: CGVector) {
        let horizontalMargin = radius + 36
        let topMargin = radius + 10
        let bottomMargin = radius + 34
        var constrained = point
        var constrainedVelocity = velocity

        let minX = horizontalMargin
        let maxX = max(horizontalMargin, size.width - horizontalMargin)
        let minY = topMargin
        let maxY = max(topMargin, size.height - bottomMargin)

        if constrained.x < minX {
            constrained.x = minX
            constrainedVelocity.dx = abs(constrainedVelocity.dx) * wallRestitution
        } else if constrained.x > maxX {
            constrained.x = maxX
            constrainedVelocity.dx = -abs(constrainedVelocity.dx) * wallRestitution
        }

        if constrained.y < minY {
            constrained.y = minY
            constrainedVelocity.dy = abs(constrainedVelocity.dy) * wallRestitution
        } else if constrained.y > maxY {
            constrained.y = maxY
            constrainedVelocity.dy = -abs(constrainedVelocity.dy) * wallRestitution
        }

        return (constrained, constrainedVelocity)
    }

    private static func resolveCollisionPenetration(
        positions: [String: CGPoint],
        radii: [String: CGFloat],
        pinnedNodeID: String?,
        canvasSize: CGSize,
        spacingMultiplier: CGFloat,
        mobilities: [String: CGFloat],
        iterations: Int
    ) -> [String: CGPoint] {
        var resolved = positions
        let nodeIDs = resolved.keys.sorted()
        let padding = collisionPadding * spacingMultiplier

        guard nodeIDs.count > 1 else {
            return resolved
        }

        for _ in 0..<iterations {
            for index in nodeIDs.indices {
                let leftID = nodeIDs[index]

                for rightIndex in nodeIDs.index(after: index)..<nodeIDs.endIndex {
                    let rightID = nodeIDs[rightIndex]
                    guard var left = resolved[leftID], var right = resolved[rightID] else {
                        continue
                    }

                    let leftRadius = radii[leftID, default: 16]
                    let rightRadius = radii[rightID, default: 16]
                    let minimumDistance = leftRadius + rightRadius + padding
                    var delta = CGVector(dx: right.x - left.x, dy: right.y - left.y)
                    var distance = delta.length

                    if distance < 0.001 {
                        let angle = Double(index + rightIndex) * 0.9
                        delta = CGVector(dx: CGFloat(cos(angle)), dy: CGFloat(sin(angle)))
                        distance = 1
                    }

                    guard distance < minimumDistance else {
                        continue
                    }

                    let normal = CGVector(dx: delta.dx / distance, dy: delta.dy / distance)
                    let overlap = minimumDistance - distance
                    let correction = min(
                        overlap * collisionPositionCorrectionStrength,
                        maxCollisionCorrectionPerIteration
                    )
                    let leftMobility = leftID == pinnedNodeID ? 0 : mobilities[leftID, default: 1]
                    let rightMobility = rightID == pinnedNodeID ? 0 : mobilities[rightID, default: 1]
                    let totalMobility = leftMobility + rightMobility

                    guard totalMobility > 0 else {
                        continue
                    }

                    let leftCorrection = correction * (leftMobility / totalMobility)
                    let rightCorrection = correction * (rightMobility / totalMobility)
                    left.x -= normal.dx * leftCorrection
                    left.y -= normal.dy * leftCorrection
                    right.x += normal.dx * rightCorrection
                    right.y += normal.dy * rightCorrection

                    if leftID != pinnedNodeID {
                        resolved[leftID] = clamp(left, radius: leftRadius, in: canvasSize)
                    }
                    if rightID != pinnedNodeID {
                        resolved[rightID] = clamp(right, radius: rightRadius, in: canvasSize)
                    }
                }
            }
        }

        return resolved
    }

    static func clamp(_ point: CGPoint, radius: CGFloat, in size: CGSize) -> CGPoint {
        constrain(point, velocity: .zero, radius: radius, in: size).point
    }
}

private extension CGPoint {
    func distance(to point: CGPoint) -> CGFloat {
        hypot(x - point.x, y - point.y)
    }
}

extension CGVector {
    var length: CGFloat {
        hypot(dx, dy)
    }

    func dot(_ other: CGVector) -> CGFloat {
        dx * other.dx + dy * other.dy
    }

    func limited(to limit: CGFloat) -> CGVector {
        let speed = length
        guard speed > limit, speed > 0 else {
            return self
        }

        let scale = limit / speed
        return CGVector(dx: dx * scale, dy: dy * scale)
    }

    static func += (lhs: inout CGVector, rhs: CGVector) {
        lhs.dx += rhs.dx
        lhs.dy += rhs.dy
    }

    static func -= (lhs: inout CGVector, rhs: CGVector) {
        lhs.dx -= rhs.dx
        lhs.dy -= rhs.dy
    }

    static func + (lhs: CGVector, rhs: CGVector) -> CGVector {
        CGVector(dx: lhs.dx + rhs.dx, dy: lhs.dy + rhs.dy)
    }

    static func - (lhs: CGVector, rhs: CGVector) -> CGVector {
        CGVector(dx: lhs.dx - rhs.dx, dy: lhs.dy - rhs.dy)
    }
}
