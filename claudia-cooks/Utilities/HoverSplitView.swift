//
//  HoverSplitView.swift
//  claudia-cooks
//

import AppKit
import SwiftUI

struct HoverSplitView<Leading: View, Trailing: View>: View {
    @Binding var leadingWidth: CGFloat
    @Binding var trailingWidth: CGFloat
    @State private var isDividerHovered = false
    @State private var isDragging = false
    @State private var dragStartWidth: CGFloat?

    private let panelSpacing: CGFloat
    private let minLeadingWidth: CGFloat
    private let maxLeadingWidth: CGFloat
    private let minTrailingWidth: CGFloat
    private let dividerHitWidth: CGFloat = 6
    private let dividerLineWidth: CGFloat = 3

    @ViewBuilder private let leading: () -> Leading
    @ViewBuilder private let trailing: () -> Trailing

    init(
        leadingWidth: Binding<CGFloat>,
        trailingWidth: Binding<CGFloat>,
        panelSpacing: CGFloat = 32,
        minLeadingWidth: CGFloat = 360,
        maxLeadingWidth: CGFloat = .infinity,
        minTrailingWidth: CGFloat = 280,
        @ViewBuilder leading: @escaping () -> Leading,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        _leadingWidth = leadingWidth
        _trailingWidth = trailingWidth
        self.panelSpacing = panelSpacing
        self.minLeadingWidth = minLeadingWidth
        self.maxLeadingWidth = maxLeadingWidth
        self.minTrailingWidth = minTrailingWidth
        self.leading = leading
        self.trailing = trailing
    }

    var body: some View {
        GeometryReader { geometry in
            let resolvedLeadingWidth = clampedLeadingWidth(
                leadingWidth,
                totalWidth: geometry.size.width
            )
            let resolvedTrailingWidth = max(
                geometry.size.width - resolvedLeadingWidth - dividerHitWidth - panelSpacing,
                0
            )

            HStack(spacing: panelSpacing) {
                leading()
                    .frame(width: resolvedLeadingWidth)

                divider(totalWidth: geometry.size.width)

                trailing()
                    .frame(width: resolvedTrailingWidth)
            }
            .onAppear {
                trailingWidth = resolvedTrailingWidth
            }
            .onChange(of: resolvedTrailingWidth) { _, newWidth in
                applyTrailingWidth(newWidth)
            }
            .onChange(of: geometry.size.width) { _, totalWidth in
                syncWidthsForContainer(totalWidth: totalWidth)
            }
        }
    }

    private func applyTrailingWidth(_ width: CGFloat) {
        if isDragging {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                trailingWidth = width
            }
        } else {
            trailingWidth = width
        }
    }

    private func syncWidthsForContainer(totalWidth: CGFloat) {
        let clamped = clampedLeadingWidth(leadingWidth, totalWidth: totalWidth)
        let trailing = max(
            totalWidth - clamped - dividerHitWidth - panelSpacing,
            0
        )
        guard clamped != leadingWidth || trailing != trailingWidth else { return }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            leadingWidth = clamped
            trailingWidth = trailing
        }
    }

    private func applyLeadingWidth(_ width: CGFloat, totalWidth: CGFloat) {
        let clamped = clampedLeadingWidth(width, totalWidth: totalWidth)
        let trailing = max(
            totalWidth - clamped - dividerHitWidth - panelSpacing,
            0
        )

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            leadingWidth = clamped
            trailingWidth = trailing
        }
    }

    private func divider(totalWidth: CGFloat) -> some View {
        ZStack {
            Color.clear

            if isDividerHovered || isDragging {
                Rectangle()
                    .fill(.white)
                    .frame(width: dividerLineWidth)
                    .transition(.opacity)
            }
        }
        .frame(width: dividerHitWidth)
        .contentShape(Rectangle())
        .animation(.easeOut(duration: 0.12), value: isDividerHovered)
        .animation(.easeOut(duration: 0.12), value: isDragging)
        .onHover { hovering in
            isDividerHovered = hovering
            updateResizeCursor(hovering: hovering || isDragging)
        }
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { value in
                    if dragStartWidth == nil {
                        dragStartWidth = leadingWidth
                        isDragging = true
                        updateResizeCursor(hovering: true)
                    }

                    let startWidth = dragStartWidth ?? leadingWidth
                    let dragDistance = value.location.x - value.startLocation.x
                    applyLeadingWidth(
                        startWidth + dragDistance,
                        totalWidth: totalWidth
                    )
                }
                .onEnded { _ in
                    dragStartWidth = nil
                    isDragging = false
                    updateResizeCursor(hovering: isDividerHovered)
                }
        )
    }

    private func clampedLeadingWidth(_ width: CGFloat, totalWidth: CGFloat) -> CGFloat {
        let reservedForTrailing = dividerHitWidth + panelSpacing + minTrailingWidth
        let availableForLeading = totalWidth - reservedForTrailing
        let cappedMax = min(max(availableForLeading, 0), maxLeadingWidth)

        guard totalWidth >= minLeadingWidth + reservedForTrailing else {
            let tightLeading = totalWidth - dividerHitWidth - panelSpacing - minTrailingWidth
            return min(max(width, 0), max(tightLeading, 0))
        }

        return min(max(width, minLeadingWidth), max(cappedMax, minLeadingWidth))
    }

    private func updateResizeCursor(hovering: Bool) {
        if hovering {
            NSCursor.resizeLeftRight.push()
        } else {
            NSCursor.pop()
        }
    }
}
