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
    var pendingDiff: RecipeEditPendingDiff? = nil
    var isInteractive: Bool = true
    var onMarkdownChange: ((String) -> Void)? = nil
    var onPendingDiffMarkdownChange: ((PendingDiffMarkdownUpdate) -> Void)? = nil
    var onAcceptPendingChange: ((UUID) -> Void)? = nil
    var onDenyPendingChange: ((UUID) -> Void)? = nil
    var recipeEditUndoManager: UndoManager? = nil
    var recipeEditReviewUndoRevision: Int = 0

    var body: some View {
        MarkdownRecipePreview(
            markdown: markdown,
            framework: framework,
            pendingDiff: pendingDiff,
            isInteractive: isInteractive,
            onMarkdownChange: onMarkdownChange,
            onPendingDiffMarkdownChange: onPendingDiffMarkdownChange,
            onAcceptPendingChange: onAcceptPendingChange,
            onDenyPendingChange: onDenyPendingChange,
            recipeEditUndoManager: recipeEditUndoManager,
            recipeEditReviewUndoRevision: recipeEditReviewUndoRevision
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
    var pendingDiff: RecipeEditPendingDiff? = nil
    var isInteractive: Bool = true
    var onMarkdownChange: ((String) -> Void)? = nil
    var onPendingDiffMarkdownChange: ((PendingDiffMarkdownUpdate) -> Void)? = nil
    var onAcceptPendingChange: ((UUID) -> Void)? = nil
    var onDenyPendingChange: ((UUID) -> Void)? = nil
    var recipeEditUndoManager: UndoManager? = nil
    var recipeEditReviewUndoRevision: Int = 0

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onMarkdownChange: onMarkdownChange,
            onPendingDiffMarkdownChange: onPendingDiffMarkdownChange,
            onAcceptPendingChange: onAcceptPendingChange,
            onDenyPendingChange: onDenyPendingChange
        )
    }

    func makeNSView(context: Context) -> RecipePreviewWebView {
        let webView = RecipePreviewWebView(messageHandler: context.coordinator)
        webView.recipeEditUndoManager = recipeEditUndoManager
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        load(into: webView, coordinator: context.coordinator)
        return webView
    }

    func updateNSView(_ webView: RecipePreviewWebView, context: Context) {
        context.coordinator.onMarkdownChange = onMarkdownChange
        context.coordinator.onPendingDiffMarkdownChange = onPendingDiffMarkdownChange
        context.coordinator.onAcceptPendingChange = onAcceptPendingChange
        context.coordinator.onDenyPendingChange = onDenyPendingChange
        webView.recipeEditUndoManager = recipeEditUndoManager

        let pendingDiffFingerprint = pendingDiff.map(PendingDiffDisplayFingerprint.init)
        let shouldReload: Bool

        let undoRevisionChanged = context.coordinator.lastRecipeEditReviewUndoRevision != recipeEditReviewUndoRevision

        if pendingDiff?.hasChanges == true {
            shouldReload = undoRevisionChanged
                || context.coordinator.lastPendingDiffFingerprint != pendingDiffFingerprint
                || context.coordinator.lastFramework != framework
                || context.coordinator.lastIsInteractive != isInteractive
        } else {
            shouldReload = undoRevisionChanged
                || context.coordinator.lastMarkdown != markdown
                || context.coordinator.lastFramework != framework
                || context.coordinator.lastIsInteractive != isInteractive
                || context.coordinator.lastPendingDiffFingerprint != nil
        }

        if shouldReload {
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
        coordinator.lastPendingDiff = pendingDiff
        coordinator.lastPendingDiffFingerprint = pendingDiff.map(PendingDiffDisplayFingerprint.init)
        coordinator.lastRecipeEditReviewUndoRevision = recipeEditReviewUndoRevision

        let html: String
        if let pendingDiff, pendingDiff.hasChanges {
            html = RecipeMarkdownDiffRenderer.html(
                pendingDiff: pendingDiff,
                framework: framework,
                isInteractive: isInteractive
            )
        } else {
            html = RecipeMarkdownDocument.html(
                markdown: markdown,
                framework: framework,
                isInteractive: isInteractive
            )
        }

        webView.loadHTMLString(html, baseURL: nil)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var lastMarkdown: String?
        var lastFramework: RecipeFramework?
        var lastIsInteractive = true
        var lastPendingDiff: RecipeEditPendingDiff?
        var lastPendingDiffFingerprint: PendingDiffDisplayFingerprint?
        var lastRecipeEditReviewUndoRevision: Int?
        weak var webView: RecipePreviewWebView?
        var onMarkdownChange: ((String) -> Void)?
        var onPendingDiffMarkdownChange: ((PendingDiffMarkdownUpdate) -> Void)?
        var onAcceptPendingChange: ((UUID) -> Void)?
        var onDenyPendingChange: ((UUID) -> Void)?

        init(
            onMarkdownChange: ((String) -> Void)?,
            onPendingDiffMarkdownChange: ((PendingDiffMarkdownUpdate) -> Void)?,
            onAcceptPendingChange: ((UUID) -> Void)?,
            onDenyPendingChange: ((UUID) -> Void)?
        ) {
            self.onMarkdownChange = onMarkdownChange
            self.onPendingDiffMarkdownChange = onPendingDiffMarkdownChange
            self.onAcceptPendingChange = onAcceptPendingChange
            self.onDenyPendingChange = onDenyPendingChange
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let preview = webView as? RecipePreviewWebView else { return }
            preview.prepareInlineScrolling()
            preview.syncTypographyToViewport()
            webView.evaluateJavaScript("window.bindDiffReviewPopovers && window.bindDiffReviewPopovers();", completionHandler: nil)
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            switch message.name {
            case "markdownChange":
                guard let payload = message.body as? String else {
                    return
                }

                if let data = payload.data(using: .utf8),
                   let update = try? JSONDecoder().decode(PendingDiffMarkdownUpdate.self, from: data) {
                    onPendingDiffMarkdownChange?(update)
                    return
                }

                lastMarkdown = payload
                onMarkdownChange?(payload)
            case "acceptChange":
                guard let changeIDString = messageBodyString(from: message.body),
                      let changeID = UUID(uuidString: changeIDString) else {
                    return
                }

                dispatchPendingChange(changeID, handler: onAcceptPendingChange)
            case "denyChange":
                guard let changeIDString = messageBodyString(from: message.body),
                      let changeID = UUID(uuidString: changeIDString) else {
                    return
                }

                dispatchPendingChange(changeID, handler: onDenyPendingChange)
            default:
                return
            }
        }

        private func messageBodyString(from body: Any) -> String? {
            if let string = body as? String {
                return string
            }

            if let number = body as? NSNumber {
                return number.stringValue
            }

            return nil
        }

        private func dispatchPendingChange(_ changeID: UUID, handler: ((UUID) -> Void)?) {
            guard let handler else {
                return
            }

            if Thread.isMainThread {
                handler(changeID)
            } else {
                DispatchQueue.main.async {
                    handler(changeID)
                }
            }
        }
    }
}

/// WKWebView that scrolls recipe pages inside the paper frame with viewport-aware type.
final class RecipePreviewWebView: WKWebView {
    private static let typographyReferenceWidth: CGFloat = 320
    private static let minimumRootFontPoints: CGFloat = 9
    private static let maximumRootFontPoints: CGFloat = 11
    private static let baseRootFontPoints: CGFloat = 10

    weak var recipeEditUndoManager: UndoManager?

    override var undoManager: UndoManager? {
        recipeEditUndoManager ?? super.undoManager
    }

    init(messageHandler: WKScriptMessageHandler) {
        let configuration = WKWebViewConfiguration()
        configuration.suppressesIncrementalRendering = true
        configuration.userContentController.add(messageHandler, name: "markdownChange")
        configuration.userContentController.add(messageHandler, name: "acceptChange")
        configuration.userContentController.add(messageHandler, name: "denyChange")
        super.init(frame: .zero, configuration: configuration)
        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if handleRecipeEditUndoKeyEquivalent(event) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    @discardableResult
    private func performRecipeEditUndo() -> Bool {
        guard let recipeEditUndoManager, recipeEditUndoManager.canUndo else {
            return false
        }
        recipeEditUndoManager.undo()
        return true
    }

    @discardableResult
    private func performRecipeEditRedo() -> Bool {
        guard let recipeEditUndoManager, recipeEditUndoManager.canRedo else {
            return false
        }
        recipeEditUndoManager.redo()
        return true
    }

    private func handleRecipeEditUndoKeyEquivalent(_ event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command),
              event.charactersIgnoringModifiers?.lowercased() == "z" else {
            return false
        }

        if event.modifierFlags.contains(.shift) {
            return performRecipeEditRedo()
        }
        return performRecipeEditUndo()
    }

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
