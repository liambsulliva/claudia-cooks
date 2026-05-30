//
//  StackedPaperPreview.swift
//  claudia-cooks
//

import SwiftUI

struct PaperSheet: Identifiable, Equatable {
    let id: UUID
    let data: Data?
    let isBlank: Bool
    let framework: RecipeFramework
}

struct StackedPaperPreview: View {
    let sheets: [PaperSheet]
    let selectedSheetID: UUID
    let isGenerating: Bool
    let maxPaperHeight: CGFloat
    var containerWidth: CGFloat?

    @State private var hasRaisedStack = false

    private let trailingPadding: CGFloat = 42
    private let maxStackDepth = 7

    private var orderedSheets: [PaperSheet] {
        let selected = sheets.filter { $0.id == selectedSheetID }
        let background = sheets.filter { $0.id != selectedSheetID }
        return background + selected
    }

    var body: some View {
        GeometryReader { geometry in
            let layout = paperLayout(in: geometry.size)

            ZStack(alignment: .bottomTrailing) {
                ForEach(Array(orderedSheets.enumerated()), id: \.element.id) { index, sheet in
                    let depthFromTop = orderedSheets.count - index - 1
                    paperView(for: sheet, isActive: sheet.id == selectedSheetID)
                        .frame(width: layout.width, height: layout.height)
                        .scaleEffect(scale(forDepth: depthFromTop), anchor: .bottomTrailing)
                        .rotationEffect(.degrees(rotation(forDepth: depthFromTop)))
                        .offset(
                            x: xOffset(forDepth: depthFromTop),
                            y: yOffset(forDepth: depthFromTop)
                        )
                        .zIndex(Double(index))
                        .shadow(
                            color: .black.opacity(sheet.id == selectedSheetID ? 0.22 : 0.12),
                            radius: sheet.id == selectedSheetID ? 22 : 12,
                            x: 0,
                            y: sheet.id == selectedSheetID ? 18 : 10
                        )
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.96)),
                                removal: .opacity.combined(with: .scale(scale: 0.96))
                            )
                        )
                }

                if isGenerating {
                    generatingBadge
                        .padding(.trailing, 22)
                        .padding(.bottom, min(layout.height - 48, 28))
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        .zIndex(Double(orderedSheets.count) + 1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(.trailing, trailingPadding)
            .padding(.bottom, hasRaisedStack ? 0 : -140)
            .animation(.spring(response: 0.58, dampingFraction: 0.82), value: stackAnimationKey)
            .animation(.spring(response: 0.42, dampingFraction: 0.86), value: layout.width)
            .animation(.spring(response: 0.42, dampingFraction: 0.86), value: layout.height)
            .animation(.spring(response: 0.72, dampingFraction: 0.78), value: hasRaisedStack)
            .onAppear {
                hasRaisedStack = false
                withAnimation(.spring(response: 0.72, dampingFraction: 0.78).delay(0.08)) {
                    hasRaisedStack = true
                }
            }
        }
    }

    @ViewBuilder
    private func paperView(for sheet: PaperSheet, isActive: Bool) -> some View {
        Group {
            if sheet.isBlank || sheet.data == nil {
                FramedBlankPagePreview(framework: sheet.framework)
            } else if let data = sheet.data {
                FramedPDFPreview(data: data)
            }
        }
        .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    sheet.framework.accentColor.opacity(isActive ? 0.5 : 0.18),
                    lineWidth: isActive ? 1.25 : 1
                )
        }
        .overlay(alignment: .topTrailing) {
            if isActive {
                Circle()
                    .fill(sheet.framework.accentColor)
                    .frame(width: 9, height: 9)
                    .padding(18)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .allowsHitTesting(isActive)
    }

    private var generatingBadge: some View {
        Label("Updating PDF", systemImage: "sparkles")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.regularMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(.separator.opacity(0.35), lineWidth: 1)
            }
    }

    private var stackAnimationKey: String {
        orderedSheets.map(\.id.uuidString).joined(separator: "-") + "-\(selectedSheetID.uuidString)-\(isGenerating)"
    }

    private func paperLayout(in containerSize: CGSize) -> (width: CGFloat, height: CGFloat) {
        let clampedWidth = min(containerSize.width, containerWidth ?? containerSize.width)
        let availableWidth = max(clampedWidth - trailingPadding, 1)
        let availableHeight = max(containerSize.height * 0.95, 1)

        let naturalHeight = min(maxPaperHeight, availableHeight)
        let naturalWidth = naturalHeight * 0.77
        let stackOverhang = CGFloat(min(max(orderedSheets.count - 1, 0), maxStackDepth)) * 18
        let widthScale = min(1, availableWidth / max(naturalWidth + stackOverhang, 1))
        let heightScale = min(1, availableHeight / max(naturalHeight, 1))
        let fitScale = min(widthScale, heightScale)

        return (
            width: max(naturalWidth * fitScale, 120),
            height: max(naturalHeight * fitScale, 156)
        )
    }

    private func xOffset(forDepth depth: Int) -> CGFloat {
        -CGFloat(min(depth, maxStackDepth)) * 18
    }

    private func yOffset(forDepth depth: Int) -> CGFloat {
        hasRaisedStack ? CGFloat(min(depth, maxStackDepth)) * 10 : 150
    }

    private func scale(forDepth depth: Int) -> CGFloat {
        1 - CGFloat(min(depth, maxStackDepth)) * 0.012
    }

    private func rotation(forDepth depth: Int) -> Double {
        -Double(min(depth, maxStackDepth)) * 0.6
    }
}

#Preview {
    let selectedID = UUID()

    StackedPaperPreview(
        sheets: [
            PaperSheet(id: UUID(), data: nil, isBlank: true, framework: .bowl),
            PaperSheet(id: UUID(), data: nil, isBlank: true, framework: .soup),
            PaperSheet(id: selectedID, data: nil, isBlank: true, framework: .sandwich)
        ],
        selectedSheetID: selectedID,
        isGenerating: true,
        maxPaperHeight: 540,
        containerWidth: 520
    )
    .frame(width: 520, height: 680)
}
