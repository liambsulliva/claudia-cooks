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
    private let minTrailingWidth: CGFloat
    private let dividerHitWidth: CGFloat = 6
    private let dividerLineWidth: CGFloat = 3

    @ViewBuilder private let leading: () -> Leading
    @ViewBuilder private let trailing: () -> Trailing

    init(
        leadingWidth: Binding<CGFloat>,
        trailingWidth: Binding<CGFloat>,
        panelSpacing: CGFloat = 64,
        minLeadingWidth: CGFloat = 360,
        minTrailingWidth: CGFloat = 280,
        @ViewBuilder leading: @escaping () -> Leading,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        _leadingWidth = leadingWidth
        _trailingWidth = trailingWidth
        self.panelSpacing = panelSpacing
        self.minLeadingWidth = minLeadingWidth
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
                trailingWidth = newWidth
            }
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
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    if dragStartWidth == nil {
                        dragStartWidth = leadingWidth
                        isDragging = true
                        updateResizeCursor(hovering: true)
                    }

                    let startWidth = dragStartWidth ?? leadingWidth
                    leadingWidth = clampedLeadingWidth(
                        startWidth + value.translation.width,
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
        let maxLeadingWidth = totalWidth - minTrailingWidth - dividerHitWidth - panelSpacing
        return min(max(width, minLeadingWidth), max(maxLeadingWidth, minLeadingWidth))
    }

    private func updateResizeCursor(hovering: Bool) {
        if hovering {
            NSCursor.resizeLeftRight.push()
        } else {
            NSCursor.pop()
        }
    }
}
