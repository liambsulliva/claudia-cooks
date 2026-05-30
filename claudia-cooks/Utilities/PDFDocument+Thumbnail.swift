//
//  PDFDocument+Thumbnail.swift
//  claudia-cooks
//

import AppKit
import PDFKit

extension PDFDocument {
    static func from(data: Data) -> PDFDocument? {
        PDFDocument(data: data)
    }

    func firstPageThumbnail(size: CGSize) -> NSImage? {
        guard let page = page(at: 0) else {
            return nil
        }

        return page.thumbnail(of: size, for: .mediaBox)
    }
}
