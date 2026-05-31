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

    private static let collisionPadding: CGFloat = 6
    private static let edgeRestLength: CGFloat = 118
    private static let edgeStretchLimit: CGFloat = 96
    private static let edgeSpring: CGFloat = 18
    private static let edgeSnapSpring: CGFloat = 76
    private static let edgeDamping: CGFloat = 5.2
    private static let collisionSpring: CGFloat = 420
    private static let airDrag: CGFloat = 4.8
    private static let velocityLimit: CGFloat = 1_400
    private static let wallRestitution: CGFloat = 0.48
    /// Per-frame velocity retention at 60 fps (~0.97 ≈ noticeable drag, settles within ~1–2 s).
    private static let frameDamping: CGFloat = 0.972

    static func step(
        positions: [String: CGPoint],
        velocities: [String: CGVector],
        radii: [String: CGFloat],
        edges: [IngredientGraphEdge],
        dragTarget: DragTarget?,
        canvasSize: CGSize,
        deltaTime: CGFloat
    ) -> (positions: [String: CGPoint], velocities: [String: CGVector]) {
        var nextPositions = positions
        var nextVelocities = velocities
        let pinnedNodeID = dragTarget?.nodeID
        var simulationPositions = positions

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

        applyEdgeSprings(edges: edges, positions: simulationPositions, velocities: velocities, forces: &forces)
        applyCollisionForces(positions: simulationPositions, radii: radii, forces: &forces)
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

            velocity.dx += force.dx * deltaTime
            velocity.dy += force.dy * deltaTime
            velocity = velocity.limited(to: velocityLimit)

            let damping = pow(frameDamping, deltaTime * 60)
            velocity.dx *= damping
            velocity.dy *= damping

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

        let separated = resolveCollisionPenetration(
            positions: nextPositions,
            radii: radii,
            pinnedNodeID: pinnedNodeID,
            canvasSize: canvasSize,
            iterations: 2
        )

        for (nodeID, point) in separated {
            nextPositions[nodeID] = point
        }

        if let dragTarget {
            let radius = radii[dragTarget.nodeID, default: 16]
            nextPositions[dragTarget.nodeID] = clamp(dragTarget.point, radius: radius, in: canvasSize)
            nextVelocities[dragTarget.nodeID] = .zero
        }

        return (nextPositions, nextVelocities)
    }

    private static func applyEdgeSprings(
        edges: [IngredientGraphEdge],
        positions: [String: CGPoint],
        velocities: [String: CGVector],
        forces: inout [String: CGVector]
    ) {
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
            let restLength = edgeRestLength + CGFloat(edge.recipeCount - 1) * 10
            let stretch = distance - restLength
            let overLimit = max(abs(stretch) - edgeStretchLimit, 0)
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
        forces: inout [String: CGVector]
    ) {
        let nodeIDs = positions.keys.sorted()

        for index in nodeIDs.indices {
            let leftID = nodeIDs[index]

            for rightIndex in nodeIDs.index(after: index)..<nodeIDs.endIndex {
                let rightID = nodeIDs[rightIndex]
                guard let left = positions[leftID], let right = positions[rightID] else {
                    continue
                }

                let minimumDistance = radii[leftID, default: 16] + radii[rightID, default: 16] + collisionPadding
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
                let force = CGVector(dx: normal.dx * overlap * collisionSpring, dy: normal.dy * overlap * collisionSpring)

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
        iterations: Int
    ) -> [String: CGPoint] {
        var resolved = positions
        let nodeIDs = resolved.keys.sorted()

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
                    let minimumDistance = leftRadius + rightRadius + collisionPadding
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

                    switch (leftID == pinnedNodeID, rightID == pinnedNodeID) {
                    case (true, false):
                        right.x += normal.dx * overlap
                        right.y += normal.dy * overlap
                    case (false, true):
                        left.x -= normal.dx * overlap
                        left.y -= normal.dy * overlap
                    case (true, true):
                        continue
                    case (false, false):
                        let halfOverlap = overlap / 2
                        left.x -= normal.dx * halfOverlap
                        left.y -= normal.dy * halfOverlap
                        right.x += normal.dx * halfOverlap
                        right.y += normal.dy * halfOverlap
                    }

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
