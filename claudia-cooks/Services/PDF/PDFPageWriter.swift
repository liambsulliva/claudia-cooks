//
//  PDFPageWriter.swift
//  claudia-cooks
//

import AppKit
import PDFKit

final class PDFPageWriter {
    private let document: PDFDocument
    private let pageSize = NSSize(width: 612, height: 792)
    private let margin: CGFloat = 54
    private var image: NSImage
    private var y: CGFloat = 54

    init(document: PDFDocument) {
        self.document = document
        self.image = NSImage(size: pageSize)
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: pageSize).fill()
    }

    func header(framework: RecipeFramework) {
        let attributes = attributes(font: .systemFont(ofSize: 14, weight: .medium), color: framework.nsAccentColor)
        drawText(framework.title.uppercased(), attributes: attributes, spacingAfter: 26)
    }

    func title(_ text: String, color: NSColor) {
        drawText(text, attributes: attributes(font: .systemFont(ofSize: 30, weight: .bold), color: color), spacingAfter: 16)
    }

    func section(_ text: String) {
        drawText(text, attributes: attributes(font: .systemFont(ofSize: 18, weight: .semibold), color: .labelColor), spacingBefore: 16, spacingAfter: 8)
    }

    func paragraph(_ text: String) {
        drawText(text, attributes: attributes(font: .systemFont(ofSize: 13), color: .secondaryLabelColor), spacingAfter: 10)
    }

    func bullets(_ items: [String]) {
        guard !items.isEmpty else {
            paragraph("No selections yet.")
            return
        }

        for item in items {
            drawText("• \(item)", attributes: attributes(font: .systemFont(ofSize: 12), color: .labelColor), indent: 14, spacingAfter: 5)
        }
    }

    func numbered(_ items: [String]) {
        guard !items.isEmpty else {
            paragraph("No steps generated yet.")
            return
        }

        for (index, item) in items.enumerated() {
            drawText("\(index + 1). \(item)", attributes: attributes(font: .systemFont(ofSize: 12), color: .labelColor), indent: 18, spacingAfter: 6)
        }
    }

    func finishPage() {
        image.unlockFocus()

        if let page = PDFPage(image: image) {
            document.insert(page, at: document.pageCount)
        }
    }

    private func drawText(
        _ text: String,
        attributes: [NSAttributedString.Key: Any],
        indent: CGFloat = 0,
        spacingBefore: CGFloat = 0,
        spacingAfter: CGFloat = 0
    ) {
        let attributedText = NSAttributedString(string: text, attributes: attributes)
        let width = pageSize.width - (margin * 2) - indent
        let proposedRect = NSRect(x: margin + indent, y: y + spacingBefore, width: width, height: .greatestFiniteMagnitude)
        let bounds = attributedText.boundingRect(
            with: proposedRect.size,
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        let height = ceil(bounds.height)

        if proposedRect.minY + height > pageSize.height - margin {
            finishPage()
            image = NSImage(size: pageSize)
            image.lockFocus()
            NSColor.white.setFill()
            NSRect(origin: .zero, size: pageSize).fill()
            y = margin
        }

        let rect = NSRect(x: margin + indent, y: y + spacingBefore, width: width, height: height)
        attributedText.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading])
        y = rect.maxY + spacingAfter
    }

    private func attributes(font: NSFont, color: NSColor) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3

        return [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
    }
}
