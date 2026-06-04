//
//  IngredientVariantMenuPresentation.swift
//  claudia-cooks
//

import AppKit
import SwiftUI

struct RightClickGesture: NSGestureRecognizerRepresentable {
    let onRightClick: () -> Void

    func makeNSGestureRecognizer(context: Context) -> NSClickGestureRecognizer {
        let recognizer = NSClickGestureRecognizer()
        recognizer.buttonMask = 0x2
        return recognizer
    }

    func handleNSGestureRecognizerAction(_ recognizer: NSClickGestureRecognizer, context: Context) {
        onRightClick()
    }

    func updateNSGestureRecognizer(_ recognizer: NSClickGestureRecognizer, context: Context) {}
}

enum IngredientVariantMenuMetrics {
    static let width: CGFloat = 160
    static let gap: CGFloat = 2
    static let verticalPadding: CGFloat = 4
    static let rowHeight: CGFloat = 26

    static func estimatedFrame(anchoredTo chipFrame: CGRect, variantCount: Int) -> CGRect {
        let height = verticalPadding * 2 + rowHeight * CGFloat(variantCount)
        return CGRect(
            x: chipFrame.maxX + gap,
            y: chipFrame.minY,
            width: width,
            height: height
        )
    }
}

struct IngredientVariantMenuPresentation: Equatable {
    let category: IngredientCategory
    let option: String
    let chipFrame: CGRect
    let isHoldSelecting: Bool
    let dragGlobalLocation: CGPoint?
}

private struct IngredientVariantMenuPresentationKey: PreferenceKey {
    static var defaultValue: IngredientVariantMenuPresentation?

    static func reduce(value: inout IngredientVariantMenuPresentation?, nextValue: () -> IngredientVariantMenuPresentation?) {
        if let next = nextValue() {
            value = next
        }
    }
}

private struct IngredientVariantMenuHostFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero {
            value = next
        }
    }
}

struct IngredientVariantMenuHost: ViewModifier {
    @Environment(IngredientCatalogStore.self) private var ingredientCatalog

    let selectionState: (String, IngredientCategory) -> IngredientOptionSelectionState
    let onToggleVariant: (String, String, IngredientCategory) -> Void
    let onDismiss: () -> Void

    @State private var presentation: IngredientVariantMenuPresentation?
    @State private var hostFrame: CGRect = .zero
    @State private var menuFrame: CGRect = .zero
    @State private var hoveredVariant: String?

    func body(content: Content) -> some View {
        content
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .preference(
                            key: IngredientVariantMenuHostFrameKey.self,
                            value: proxy.frame(in: .global)
                        )
                }
            }
            .onPreferenceChange(IngredientVariantMenuPresentationKey.self) { newPresentation in
                presentation = newPresentation
                if newPresentation == nil {
                    hoveredVariant = nil
                }
            }
            .onPreferenceChange(IngredientVariantMenuHostFrameKey.self) { hostFrame = $0 }
            .overlay {
                if let presentation, hostFrame != .zero {
                    ZStack(alignment: .topLeading) {
                        if !presentation.isHoldSelecting {
                            Color.clear
                                .frame(width: hostFrame.width, height: hostFrame.height)
                                .contentShape(Rectangle())
                                .onTapGesture(perform: onDismiss)
                        }

                        variantMenu(for: presentation)
                            .offset(
                                x: presentation.chipFrame.maxX + IngredientVariantMenuMetrics.gap - hostFrame.minX,
                                y: presentation.chipFrame.minY - hostFrame.minY
                            )
                    }
                    .frame(width: hostFrame.width, height: hostFrame.height, alignment: .topLeading)
                    .transition(.opacity)
                }
            }
            .zIndex(presentation == nil ? 0 : 1_000)
            .animation(.spring(response: 0.2, dampingFraction: 0.86), value: presentation)
    }

    @ViewBuilder
    private func variantMenu(for presentation: IngredientVariantMenuPresentation) -> some View {
        if let variants = ingredientCatalog.variants(for: presentation.option) {
            let selection = selectionState(presentation.option, presentation.category)

            GlassEffectContainer(spacing: 8) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(variants, id: \.self) { variant in
                        Button {
                            onToggleVariant(presentation.option, variant, presentation.category)
                            onDismiss()
                        } label: {
                            variantRow(
                                variant,
                                category: presentation.category,
                                isPointerHighlighted: isPointerHighlighted(
                                    variant,
                                    presentation: presentation
                                ),
                                isSelected: selection.isVariantSelected(variant),
                                usesStrongHighlight: presentation.isHoldSelecting
                            )
                            .frame(height: IngredientVariantMenuMetrics.rowHeight)
                            .onHover { isHovering in
                                if isHovering {
                                    hoveredVariant = variant
                                } else if hoveredVariant == variant {
                                    hoveredVariant = nil
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, IngredientVariantMenuMetrics.verticalPadding)
                .frame(width: IngredientVariantMenuMetrics.width, alignment: .leading)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.22), radius: 20, x: 0, y: 12)
                .background {
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear {
                                menuFrame = proxy.frame(in: .global)
                            }
                            .onChange(of: proxy.frame(in: .global)) { _, frame in
                                menuFrame = frame
                            }
                    }
                }
            }
            .allowsHitTesting(!presentation.isHoldSelecting)
        }
    }

    private func isPointerHighlighted(
        _ variant: String,
        presentation: IngredientVariantMenuPresentation
    ) -> Bool {
        if presentation.isHoldSelecting,
           let dragGlobalLocation = presentation.dragGlobalLocation,
           variantName(
               atGlobalPoint: dragGlobalLocation,
                   variants: ingredientCatalog.variants(for: presentation.option) ?? []
           ) == variant {
            return true
        }

        return hoveredVariant == variant
    }

    private func variantName(atGlobalPoint point: CGPoint, variants: [String]) -> String? {
        guard menuFrame != .zero else {
            return nil
        }

        let localX = point.x - menuFrame.minX
        let localY = point.y - menuFrame.minY

        guard localX >= 0,
              localX <= IngredientVariantMenuMetrics.width,
              localY >= IngredientVariantMenuMetrics.verticalPadding else {
            return nil
        }

        let index = Int((localY - IngredientVariantMenuMetrics.verticalPadding) / IngredientVariantMenuMetrics.rowHeight)
        guard variants.indices.contains(index) else {
            return nil
        }

        return variants[index]
    }

    private func variantRow(
        _ variant: String,
        category: IngredientCategory,
        isPointerHighlighted: Bool,
        isSelected: Bool,
        usesStrongHighlight: Bool
    ) -> some View {
        let isEmphasized = isPointerHighlighted || isSelected

        return HStack(spacing: 8) {
            Text(variant)
                .font(.caption.weight(isEmphasized ? .semibold : .regular))
                .foregroundStyle(.black)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 8)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(category.accentColor)
            }
        }
        .padding(.horizontal, 12)
        .background {
            if isEmphasized {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        category.accentColor.opacity(
                            isPointerHighlighted && usesStrongHighlight ? 0.28 : 0.22
                        )
                    )
                    .padding(.horizontal, 6)
                    .padding(.vertical, -4)
            }
        }
    }
}

extension View {
    func ingredientVariantMenuHost(
        selectionState: @escaping (String, IngredientCategory) -> IngredientOptionSelectionState,
        onToggleVariant: @escaping (String, String, IngredientCategory) -> Void,
        onDismiss: @escaping () -> Void
    ) -> some View {
        modifier(
            IngredientVariantMenuHost(
                selectionState: selectionState,
                onToggleVariant: onToggleVariant,
                onDismiss: onDismiss
            )
        )
    }

    func ingredientVariantMenuPresentation(_ presentation: IngredientVariantMenuPresentation?) -> some View {
        preference(key: IngredientVariantMenuPresentationKey.self, value: presentation)
    }
}
