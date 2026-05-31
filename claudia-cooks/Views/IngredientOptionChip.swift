//
//  IngredientOptionChip.swift
//  claudia-cooks
//

import SwiftUI

struct IngredientOptionChip: View {
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
        IngredientCatalog.variants(for: option)
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

        if isActive {
            Button(action: handleTap) {
                label
            }
            .buttonStyle(.glassProminent)
            .tint(category.accentColor)
            .buttonBorderShape(.roundedRectangle(radius: 10))
            .simultaneousGesture(variantHoldGesture)
            .gesture(RightClickGesture(onRightClick: presentVariantMenuFromRightClick))
        } else {
            Button(action: handleTap) {
                label
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.roundedRectangle(radius: 10))
            .simultaneousGesture(variantHoldGesture)
            .gesture(RightClickGesture(onRightClick: presentVariantMenuFromRightClick))
        }
    }

    private var chipLabel: some View {
        VStack(spacing: 2) {
            Text(option)
                .font(.caption)
                .fontWeight(isActive ? .semibold : .regular)
                .lineLimit(1)

            if !selectionState.variants.isEmpty {
                Text(selectionState.variants.joined(separator: ", "))
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
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
