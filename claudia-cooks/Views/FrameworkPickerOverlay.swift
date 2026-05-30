//
//  FrameworkPickerOverlay.swift
//  claudia-cooks
//

import SwiftUI

struct FrameworkPickerOverlay: View {
    let onSelect: (RecipeFramework) -> Void
    let onClose: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ZStack {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.55)

                    Rectangle()
                        .fill(.black.opacity(0.22))
                }
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)

                pickerPane(maxHeight: geometry.size.height - 72)
            }
        }
        .onExitCommand(perform: onClose)
    }

    private func pickerPane(maxHeight: CGFloat) -> some View {
        VStack(alignment: .trailing, spacing: 12) {
            Button {
                onClose()
            } label: {
                Label("Close", systemImage: "xmark")
                    .labelStyle(.iconOnly)
                    .font(.headline)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)

            ScrollView {
                RecipeFrameworksSection(onSelect: onSelect)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            .scrollIndicators(.hidden)
        }
        .padding(32)
        .frame(maxWidth: 900)
        .frame(maxHeight: maxHeight)
        .fixedSize(horizontal: false, vertical: true)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.separator.opacity(0.35), lineWidth: 1)
        }
        .transition(.scale(scale: 0.98).combined(with: .opacity))
    }
}

#Preview {
    FrameworkPickerOverlay(
        onSelect: { _ in },
        onClose: {}
    )
    .frame(width: 900, height: 700)
}
