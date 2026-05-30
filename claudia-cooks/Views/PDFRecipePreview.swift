//
//  PDFRecipePreview.swift
//  claudia-cooks
//

import PDFKit
import SwiftUI

struct FramedPDFPreview: View {
    let data: Data

    var body: some View {
        PDFRecipePreview(data: data)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(.separator.opacity(0.55), lineWidth: 1)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FramedBlankPagePreview: View {
    let framework: RecipeFramework

    var body: some View {
        BlankPageView(framework: framework, style: .full)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(.separator.opacity(0.55), lineWidth: 1)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PDFRecipePreview: NSViewRepresentable {
    let data: Data

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> InteractivePDFView {
        let pdfView = InteractivePDFView()
        loadDocument(into: pdfView, data: data, coordinator: context.coordinator)
        return pdfView
    }

    func updateNSView(_ pdfView: InteractivePDFView, context: Context) {
        if context.coordinator.lastData != data {
            loadDocument(into: pdfView, data: data, coordinator: context.coordinator)
        } else {
            pdfView.refitAndCenter()
        }
    }

    private func loadDocument(
        into pdfView: InteractivePDFView,
        data: Data,
        coordinator: Coordinator
    ) {
        guard let document = PDFDocument(data: data) else {
            return
        }

        coordinator.lastData = data
        pdfView.document = document
        pdfView.refitAndCenter()
    }

    final class Coordinator {
        var lastData: Data?
    }
}
