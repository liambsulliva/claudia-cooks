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

    func makeNSView(context: Context) -> FitToViewWebView {
        let webView = FitToViewWebView(messageHandler: context.coordinator)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        load(into: webView, coordinator: context.coordinator)
        return webView
    }

    func updateNSView(_ webView: FitToViewWebView, context: Context) {
        context.coordinator.onMarkdownChange = onMarkdownChange

        if context.coordinator.lastMarkdown != markdown
            || context.coordinator.lastFramework != framework
            || context.coordinator.lastIsInteractive != isInteractive {
            load(into: webView, coordinator: context.coordinator)
        } else {
            webView.refitContent()
        }
    }

    private func load(into webView: FitToViewWebView, coordinator: Coordinator) {
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
        weak var webView: FitToViewWebView?
        var onMarkdownChange: ((String) -> Void)?

        init(onMarkdownChange: ((String) -> Void)?) {
            self.onMarkdownChange = onMarkdownChange
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            (webView as? FitToViewWebView)?.refitContent()
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

final class FitToViewWebView: WKWebView {
    private var lastFittedSize: CGSize = .zero

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

    private func configure() {
        setValue(false, forKey: "drawsBackground")
    }

    override func layout() {
        super.layout()

        guard bounds.width > 0, bounds.height > 0 else {
            return
        }

        if abs(bounds.width - lastFittedSize.width) > 0.5
            || abs(bounds.height - lastFittedSize.height) > 0.5 {
            refitContent()
        }
    }

    func refitContent() {
        guard bounds.width > 0, bounds.height > 0 else {
            return
        }

        let fitScript = """
        (function() {
            document.body.style.transform = 'none';
            document.body.style.width = 'auto';
            var width = Math.max(document.body.scrollWidth, document.documentElement.scrollWidth);
            var height = Math.max(document.body.scrollHeight, document.documentElement.scrollHeight);
            return { width: width, height: height };
        })();
        """

        evaluateJavaScript(fitScript) { [weak self] result, _ in
            guard let self,
                  let payload = result as? [String: Double],
                  let contentWidth = payload["width"],
                  let contentHeight = payload["height"],
                  contentWidth > 0,
                  contentHeight > 0 else {
                return
            }

            let widthScale = self.bounds.width / contentWidth
            let heightScale = self.bounds.height / contentHeight
            let scale = min(widthScale, heightScale, 1)
            let needsScroll = contentHeight * scale > self.bounds.height - 1

            let applyScript = """
            (function() {
                var scale = \(scale);
                var needsScroll = \(needsScroll);
                document.body.style.transformOrigin = 'top left';
                document.body.style.transform = needsScroll ? 'none' : 'scale(' + scale + ')';
                document.body.style.width = needsScroll ? '100%' : \(contentWidth) + 'px';
                document.documentElement.style.overflowY = needsScroll ? 'auto' : 'hidden';
                return scale;
            })();
            """

            self.evaluateJavaScript(applyScript) { _, _ in
                self.lastFittedSize = self.bounds.size
            }
        }
    }
}
