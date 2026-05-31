//
//  MarkdownRecipePreview.swift
//  claudia-cooks
//

import AppKit
import SwiftUI
import WebKit

struct FramedMarkdownPreview: View {
    let markdown: String
    let framework: RecipeFramework
    var isInteractive: Bool = true
    var onMarkdownChange: ((String) -> Void)?

    var body: some View {
        MarkdownRecipePreview(
            markdown: markdown,
            framework: framework,
            isInteractive: isInteractive,
            onMarkdownChange: onMarkdownChange
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.separator.opacity(0.55), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}

struct MarkdownRecipePreview: NSViewRepresentable {
    let markdown: String
    let framework: RecipeFramework
    var isInteractive: Bool = true
    var onMarkdownChange: ((String) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(onMarkdownChange: onMarkdownChange)
    }

    func makeNSView(context: Context) -> RecipePreviewWebView {
        let webView = RecipePreviewWebView(messageHandler: context.coordinator)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        load(into: webView, coordinator: context.coordinator)
        return webView
    }

    func updateNSView(_ webView: RecipePreviewWebView, context: Context) {
        context.coordinator.onMarkdownChange = onMarkdownChange

        if context.coordinator.lastMarkdown != markdown
            || context.coordinator.lastFramework != framework
            || context.coordinator.lastIsInteractive != isInteractive {
            load(into: webView, coordinator: context.coordinator)
        } else {
            webView.prepareInlineScrolling()
            webView.syncTypographyToViewport()
        }
    }

    static func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView: RecipePreviewWebView,
        context: Context
    ) -> CGSize? {
        proposal.replacingUnspecifiedDimensions(by: .zero)
    }

    private func load(into webView: RecipePreviewWebView, coordinator: Coordinator) {
        coordinator.lastMarkdown = markdown
        coordinator.lastFramework = framework
        coordinator.lastIsInteractive = isInteractive
        let html = RecipeMarkdownDocument.html(
            markdown: markdown,
            framework: framework,
            isInteractive: isInteractive
        )
        webView.loadHTMLString(html, baseURL: nil)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var lastMarkdown: String?
        var lastFramework: RecipeFramework?
        var lastIsInteractive = true
        weak var webView: RecipePreviewWebView?
        var onMarkdownChange: ((String) -> Void)?

        init(onMarkdownChange: ((String) -> Void)?) {
            self.onMarkdownChange = onMarkdownChange
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let preview = webView as? RecipePreviewWebView else { return }
            preview.prepareInlineScrolling()
            preview.syncTypographyToViewport()
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == "markdownChange",
                  let markdown = message.body as? String else {
                return
            }

            lastMarkdown = markdown
            onMarkdownChange?(markdown)
        }
    }
}

/// WKWebView that scrolls recipe pages inside the paper frame with viewport-aware type.
final class RecipePreviewWebView: WKWebView {
    private static let typographyReferenceWidth: CGFloat = 320
    private static let minimumRootFontPoints: CGFloat = 9
    private static let maximumRootFontPoints: CGFloat = 11
    private static let baseRootFontPoints: CGFloat = 10

    init(messageHandler: WKScriptMessageHandler) {
        let configuration = WKWebViewConfiguration()
        configuration.suppressesIncrementalRendering = true
        configuration.userContentController.add(messageHandler, name: "markdownChange")
        super.init(frame: .zero, configuration: configuration)
        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func layout() {
        super.layout()
        prepareInlineScrolling()
        syncTypographyToViewport()
    }

    func prepareInlineScrolling() {
        configureContentScrollViewIfNeeded()
    }

    func syncTypographyToViewport() {
        guard bounds.width > 1 else { return }

        let widthScale = bounds.width / Self.typographyReferenceWidth
        let clampedScale = min(max(widthScale, Self.minimumRootFontPoints / Self.baseRootFontPoints), Self.maximumRootFontPoints / Self.baseRootFontPoints)
        let rootFontPoints = Self.baseRootFontPoints * clampedScale
        let script = "document.documentElement.style.fontSize = '\(rootFontPoints)pt';"

        evaluateJavaScript(script, completionHandler: nil)
    }

    private func configure() {
        setValue(false, forKey: "drawsBackground")
        configureContentScrollViewIfNeeded()
    }

    private func configureContentScrollViewIfNeeded() {
        guard let scrollView = contentScrollView else { return }

        // Recipe content scrolls inside the page (`body { overflow-y: auto }`), not via this outer scroll view.
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.usesPredominantAxisScrolling = true
        scrollView.verticalScrollElasticity = .none
        scrollView.horizontalScrollElasticity = .none
        scrollView.allowsMagnification = false
    }

    private var contentScrollView: NSScrollView? {
        if let enclosingScrollView {
            return enclosingScrollView
        }

        return findScrollView(in: self)
    }

    private func findScrollView(in view: NSView) -> NSScrollView? {
        if let scrollView = view as? NSScrollView {
            return scrollView
        }

        for subview in view.subviews {
            if let scrollView = findScrollView(in: subview) {
                return scrollView
            }
        }

        return nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureContentScrollViewIfNeeded()
    }
}
