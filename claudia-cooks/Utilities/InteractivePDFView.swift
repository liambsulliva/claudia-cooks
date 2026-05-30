//
//  InteractivePDFView.swift
//  claudia-cooks
//

import AppKit
import PDFKit

final class InteractivePDFView: PDFView {
    private var lastLayoutWidth: CGFloat = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        autoScales = false
        displayMode = .singlePage
        displayDirection = .vertical
        backgroundColor = .white
        displaysPageBreaks = false
        pageShadowsEnabled = false
    }

    override func layout() {
        super.layout()

        guard document != nil, bounds.width > 0 else {
            return
        }

        if abs(bounds.width - lastLayoutWidth) > 0.5 {
            refitAndCenter()
            lastLayoutWidth = bounds.width
        }
    }

    func refitAndCenter() {
        guard let page = document?.page(at: 0),
              window != nil,
              enclosingScrollView != nil else {
            return
        }

        let pageBounds = page.bounds(for: displayBox)
        guard pageBounds.width > 0, bounds.width > 0 else {
            return
        }

        let availableWidth = bounds.width
        let fittedScale = min(max(availableWidth / pageBounds.width, 0.05), 8)
        guard fittedScale.isFinite, fittedScale > 0 else {
            return
        }

        minScaleFactor = 0.05
        maxScaleFactor = 8
        scaleFactor = fittedScale
        minScaleFactor = fittedScale
        maxScaleFactor = fittedScale

        go(to: page)
        resetScrollPosition()
    }

    private func resetScrollPosition() {
        guard let scrollView = enclosingScrollView else {
            return
        }

        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.verticalScrollElasticity = .none
        scrollView.horizontalScrollElasticity = .none
        scrollView.contentView.scroll(to: .zero)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    override func scrollWheel(with event: NSEvent) {
        nextResponder?.scrollWheel(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        // Fixed preview — no panning or text selection.
    }

    override func mouseDragged(with event: NSEvent) {
        // Fixed preview — no panning.
    }

    override func mouseUp(with event: NSEvent) {
        // Fixed preview — no panning.
    }
}
