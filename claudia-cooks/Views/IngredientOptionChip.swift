//
//  IngredientOptionChip.swift
//  claudia-cooks
//

import SwiftUI

struct IngredientOptionChip: View {
    @Environment(IngredientCatalogStore.self) private var ingredientCatalog

    let option: String
    let category: IngredientCategory
    let selectionState: IngredientOptionSelectionState
    @Binding var isMenuPresented: Bool
    let onToggle: () -> Void
    let onToggleVariant: (String) -> Void

    @State private var suppressNextTap = false
    @State private var isHoldSelecting = false
    @State private var dragGlobalLocation: CGPoint?
    @State private var chipGlobalFrame: CGRect = .zero

    private var variants: [String]? {
        ingredientCatalog.variants(for: option)
    }

    private var isActive: Bool {
        selectionState.isBaseSelected || !selectionState.variants.isEmpty
    }

    private var menuPresentation: IngredientVariantMenuPresentation? {
        guard isMenuPresented, chipGlobalFrame != .zero else {
            return nil
        }

        return IngredientVariantMenuPresentation(
            category: category,
            option: option,
            chipFrame: chipGlobalFrame,
            isHoldSelecting: isHoldSelecting,
            dragGlobalLocation: dragGlobalLocation
        )
    }

    var body: some View {
        chipButton
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            chipGlobalFrame = proxy.frame(in: .global)
                        }
                        .onChange(of: proxy.frame(in: .global)) { _, frame in
                            chipGlobalFrame = frame
                        }
                }
            }
            .ingredientVariantMenuPresentation(menuPresentation)
    }

    @ViewBuilder
    private var chipButton: some View {
        let label = chipLabel

        Group {
            if isActive {
                Button(action: handleTap) {
                    label
                }
                .buttonStyle(.glassProminent)
                .tint(category.accentColor)
            } else {
                Button(action: handleTap) {
                    label
                }
                .buttonStyle(.glass)
            }
        }
        .buttonBorderShape(.roundedRectangle(radius: 10))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .simultaneousGesture(variantHoldGesture)
        .gesture(RightClickGesture(onRightClick: presentVariantMenuFromRightClick))
    }

    private var chipLabel: some View {
        HStack(alignment: .center, spacing: ChipLabelMetrics.labelSpacing) {
            VStack(alignment: .leading, spacing: ChipLabelMetrics.lineSpacing) {
                Text(option)
                    .font(.caption)
                    .fontWeight(isActive ? .semibold : .regular)
                    .lineLimit(1)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !selectionState.variants.isEmpty {
                    Text(selectionState.variants.joined(separator: ", "))
                        .font(.system(size: ChipLabelMetrics.variantFontSize))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if variants != nil {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: ChipLabelMetrics.minContentHeight, alignment: .center)
        .frame(maxHeight: .infinity, alignment: .center)
    }

    private var variantHoldGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.38)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
            .onChanged { value in
                guard variants != nil else {
                    return
                }

                switch value {
                case .second(true, let drag):
                    isHoldSelecting = true
                    isMenuPresented = true
                    dragGlobalLocation = drag?.location
                default:
                    break
                }
            }
            .onEnded { value in
                guard variants != nil else {
                    return
                }

                isHoldSelecting = false

                switch value {
                case .second(true, let drag?):
                    isMenuPresented = true

                    if let variantName = variantName(atGlobalPoint: drag.location) {
                        selectVariant(variantName)
                    } else {
                        suppressAccidentalTapAfterHold()
                    }

                case .first(true):
                    isMenuPresented = true
                    suppressAccidentalTapAfterHold()

                default:
                    break
                }

                dragGlobalLocation = nil
            }
    }

    private func presentVariantMenuFromRightClick() {
        guard variants != nil else {
            return
        }

        isHoldSelecting = false
        dragGlobalLocation = nil
        isMenuPresented = true
    }

    private func handleTap() {
        if suppressNextTap {
            suppressNextTap = false
            return
        }

        if isMenuPresented {
            isMenuPresented = false
            return
        }

        onToggle()
    }

    private func suppressAccidentalTapAfterHold() {
        suppressNextTap = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            suppressNextTap = false
        }
    }

    private func selectVariant(_ variant: String) {
        onToggleVariant(variant)
        isMenuPresented = false
        isHoldSelecting = false
        dragGlobalLocation = nil
    }

    private func variantName(atGlobalPoint point: CGPoint) -> String? {
        guard isMenuPresented,
              let variants,
              chipGlobalFrame != .zero else {
            return nil
        }

        let menuFrame = IngredientVariantMenuMetrics.estimatedFrame(
            anchoredTo: chipGlobalFrame,
            variantCount: variants.count
        )
        let localX = point.x - menuFrame.minX
        let localY = point.y - menuFrame.minY

        guard localX >= 0,
              localX <= menuFrame.width,
              localY >= IngredientVariantMenuMetrics.verticalPadding else {
            return nil
        }

        let index = Int((localY - IngredientVariantMenuMetrics.verticalPadding) / IngredientVariantMenuMetrics.rowHeight)
        guard variants.indices.contains(index) else {
            return nil
        }

        return variants[index]
    }
}

private enum ChipLabelMetrics {
    static let lineSpacing: CGFloat = 2
    static let labelSpacing: CGFloat = 4
    static let variantFontSize: CGFloat = 9
    static let minContentHeight: CGFloat = 28
}
