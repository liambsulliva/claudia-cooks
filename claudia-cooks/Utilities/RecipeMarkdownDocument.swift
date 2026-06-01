//
//  RecipeMarkdownDocument.swift
//  claudia-cooks
//

import Foundation

enum RecipeMarkdownDocument {
    static func html(
        markdown: String,
        framework: RecipeFramework,
        isInteractive: Bool = true
    ) -> String {
        let body = MarkdownToHTML.convert(RecipeMarkdownFrontmatter.renderableBody(markdown))
        return documentHTML(
            body: body,
            framework: framework,
            isInteractive: isInteractive,
            includesDiffStyles: false,
            script: editScript(framework: framework)
        )
    }

    static func diffHTML(
        body: String,
        framework: RecipeFramework,
        isInteractive: Bool = false
    ) -> String {
        documentHTML(
            body: body,
            framework: framework,
            isInteractive: isInteractive,
            includesDiffStyles: true,
            script: diffAndEditScript(framework: framework)
        )
    }

    private static func documentHTML(
        body: String,
        framework: RecipeFramework,
        isInteractive: Bool,
        includesDiffStyles: Bool,
        script: String
    ) -> String {
        """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="color-scheme" content="light dark">
        <style>
        \(stylesheet(framework: framework, includesDiffStyles: includesDiffStyles))
        </style>
        </head>
        <body
            data-interactive="\(isInteractive ? "true" : "false")"
            contenteditable="\(isInteractive ? "true" : "false")"
            spellcheck="true"
        >
        \(body)
        <script>
        \(script)
        </script>
        </body>
        </html>
        """
    }

    private static func diffAndEditScript(framework: RecipeFramework) -> String {
        """
        (function() {
            function postReviewDecision(handlerName, changeID) {
                if (!changeID) {
                    return;
                }
                var handler = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers[handlerName];
                if (handler) {
                    handler.postMessage(changeID);
                }
            }

            window.claudiaReviewChange = function(action, button, event) {
                if (event) {
                    event.preventDefault();
                    event.stopImmediatePropagation();
                }
                var group = button && button.closest
                    ? button.closest('.diff-change-group[data-change-id]')
                    : null;
                var changeID = group ? group.getAttribute('data-change-id') : null;
                postReviewDecision(action === 'accept' ? 'acceptChange' : 'denyChange', changeID);
                return false;
            };

            function bindReviewPopovers() {
                document.querySelectorAll('.diff-change-group[data-change-id]').forEach(function(group) {
                    var changeID = group.getAttribute('data-change-id');
                    var popover = group.querySelector('.diff-review-popover');
                    var acceptButton = group.querySelector('.diff-review-y');
                    var denyButton = group.querySelector('.diff-review-n');
                    if (!changeID || !popover || !acceptButton || !denyButton) {
                        return;
                    }

                    popover.setAttribute('contenteditable', 'false');
                    [acceptButton, denyButton].forEach(function(button) {
                        button.setAttribute('contenteditable', 'false');
                        button.setAttribute('tabindex', '0');
                    });

                    function handleAccept(event) {
                        if (event) {
                            event.preventDefault();
                            event.stopImmediatePropagation();
                        }
                        postReviewDecision('acceptChange', changeID);
                        return false;
                    }

                    function handleDeny(event) {
                        if (event) {
                            event.preventDefault();
                            event.stopImmediatePropagation();
                        }
                        postReviewDecision('denyChange', changeID);
                        return false;
                    }

                    acceptButton.onclick = handleAccept;
                    denyButton.onclick = handleDeny;
                    acceptButton.onmousedown = handleAccept;
                    denyButton.onmousedown = handleDeny;
                    popover.onclick = function(event) {
                        event.stopPropagation();
                    };
                });
            }

            window.bindDiffReviewPopovers = bindReviewPopovers;
            bindReviewPopovers();

            if (document.body.dataset.interactive !== 'true') {
                return;
            }

            document.querySelectorAll('.diff-line.diff-removal').forEach(function(node) {
                node.setAttribute('contenteditable', 'false');
            });

            var pendingPost;

            function cleanText(value) {
                return (value || '').replace(/\\u00a0/g, ' ').replace(/[ \\t]+/g, ' ').trim();
            }

            function diffText(node) {
                var span = node.querySelector('.diff-text');
                return cleanText(span ? span.innerText : node.textContent);
            }

            function blockText(node) {
                if (node.classList && (node.classList.contains('diff-removal') || node.classList.contains('diff-addition'))) {
                    return diffText(node);
                }
                return cleanText(node.innerText || node.textContent || '');
            }

            function listItemText(item) {
                if (item.classList && (item.classList.contains('diff-removal') || item.classList.contains('diff-addition'))) {
                    return diffText(item);
                }
                return cleanText(item.innerText || item.textContent || '');
            }

            function collectAdditionEdits() {
                return Array.from(document.querySelectorAll('.diff-change-group[data-change-id]')).map(function(group) {
                    var addition = group.querySelector('.diff-line.diff-addition');
                    if (!addition) {
                        return null;
                    }
                    return {
                        id: group.getAttribute('data-change-id'),
                        text: diffText(addition)
                    };
                }).filter(function(edit) {
                    return edit && edit.id && edit.text;
                });
            }

            function appendSerializedLine(lines, ordered, stepNumberRef, text) {
                if (!text) {
                    return;
                }
                stepNumberRef.value += 1;
                var marker = ordered ? stepNumberRef.value + '. ' : '- ';
                lines.push(marker + text);
            }

            function serializeDiffGroupLines(group, ordered, lines, stepNumberRef) {
                Array.from(group.querySelectorAll('.diff-line')).forEach(function(line) {
                    if (line.classList.contains('diff-addition')) {
                        return;
                    }
                    appendSerializedLine(lines, ordered, stepNumberRef, diffText(line));
                });
            }

            function serializeList(list) {
                var ordered = list.tagName.toLowerCase() === 'ol';
                var lines = [];
                var stepNumber = { value: 0 };

                Array.from(list.children).forEach(function(item) {
                    if (item.classList.contains('diff-change-group')) {
                        serializeDiffGroupLines(item, ordered, lines, stepNumber);
                        return;
                    }

                    if (!item.tagName || item.tagName.toLowerCase() === 'li' || item.classList.contains('diff-unchanged')) {
                        var text = listItemText(item);
                        appendSerializedLine(lines, ordered, stepNumber, text);
                    }
                });

                return lines.join('\\n');
            }

            function serializeDiffBlock(group) {
                var blocks = [];
                Array.from(group.querySelectorAll('.diff-line')).forEach(function(line) {
                    if (line.classList.contains('diff-addition')) {
                        return;
                    }

                    var text = diffText(line);
                    if (!text) {
                        return;
                    }

                    var tag = (line.tagName || '').toLowerCase();
                    if (tag === 'h1') {
                        blocks.push('<h1 class="recipe-title" style="color: \(framework.htmlAccentHex)">' + text + '</h1>');
                    } else if (tag === 'p') {
                        blocks.push(text);
                    }
                });
                return blocks.join('\\n\\n');
            }

            function serializeMarkdown() {
                var blocks = [];
                Array.from(document.body.children).forEach(function(node) {
                    if (node.tagName && node.tagName.toLowerCase() === 'script') {
                        return;
                    }

                    if (node.classList.contains('diff-change-group')) {
                        var diffBlock = serializeDiffBlock(node);
                        if (diffBlock) {
                            blocks.push(diffBlock);
                        }
                        return;
                    }

                    var tag = (node.tagName || '').toLowerCase();
                    var text = blockText(node);

                    if (!text) {
                        return;
                    }

                    if (node.classList.contains('framework-label')) {
                        blocks.push('<p class="framework-label">' + text + '</p>');
                    } else if (tag === 'h1') {
                        blocks.push('<h1 class="recipe-title" style="color: \(framework.htmlAccentHex)">' + text + '</h1>');
                    } else if (tag === 'h2') {
                        blocks.push('## ' + text);
                    } else if (tag === 'h3') {
                        blocks.push('### ' + text);
                    } else if (tag === 'ul' || tag === 'ol') {
                        var list = serializeList(node);
                        if (list) {
                            blocks.push(list);
                        }
                    } else {
                        blocks.push(text);
                    }
                });
                return blocks.join('\\n\\n');
            }

            function postMarkdownChange() {
                window.clearTimeout(pendingPost);
                pendingPost = window.setTimeout(function() {
                    var payload = {
                        markdown: serializeMarkdown(),
                        additions: collectAdditionEdits()
                    };
                    window.webkit.messageHandlers.markdownChange.postMessage(JSON.stringify(payload));
                }, 250);
            }

            document.body.addEventListener('input', postMarkdownChange);
        })();
        """
    }

    private static func editScript(framework: RecipeFramework) -> String {
        """
        (function() {
            if (document.body.dataset.interactive !== 'true') {
                return;
            }

            var pendingPost;

            function cleanText(value) {
                return (value || '').replace(/\\u00a0/g, ' ').replace(/[ \\t]+/g, ' ').trim();
            }

            function blockText(node) {
                return cleanText(node.innerText || node.textContent || '');
            }

            function listItemText(item) {
                return cleanText(item.innerText || item.textContent || '');
            }

            function serializeList(list) {
                var ordered = list.tagName.toLowerCase() === 'ol';
                return Array.from(list.children)
                    .filter(function(item) { return item.tagName && item.tagName.toLowerCase() === 'li'; })
                    .map(function(item, index) {
                        var marker = ordered ? (index + 1) + '. ' : '- ';
                        return marker + listItemText(item);
                    })
                    .filter(function(line) { return line.trim().length > 2; })
                    .join('\\n');
            }

            function serializeMarkdown() {
                var blocks = [];
                Array.from(document.body.children).forEach(function(node) {
                    if (node.tagName && node.tagName.toLowerCase() === 'script') {
                        return;
                    }

                    var tag = (node.tagName || '').toLowerCase();
                    var text = blockText(node);

                    if (!text) {
                        return;
                    }

                    if (node.classList.contains('framework-label')) {
                        blocks.push('<p class="framework-label">' + text + '</p>');
                    } else if (tag === 'h1') {
                        blocks.push('<h1 class="recipe-title" style="color: \(framework.htmlAccentHex)">' + text + '</h1>');
                    } else if (tag === 'h2') {
                        blocks.push('## ' + text);
                    } else if (tag === 'h3') {
                        blocks.push('### ' + text);
                    } else if (tag === 'ul' || tag === 'ol') {
                        var list = serializeList(node);
                        if (list) {
                            blocks.push(list);
                        }
                    } else {
                        blocks.push(text);
                    }
                });
                return blocks.join('\\n\\n');
            }

            function postMarkdownChange() {
                window.clearTimeout(pendingPost);
                pendingPost = window.setTimeout(function() {
                    window.webkit.messageHandlers.markdownChange.postMessage(serializeMarkdown());
                }, 250);
            }

            document.body.addEventListener('input', postMarkdownChange);
        })();
        """
    }

    private static func stylesheet(framework: RecipeFramework, includesDiffStyles: Bool = false) -> String {
        var rules = """
        :root {
            color-scheme: light dark;
            --accent: \(framework.htmlAccentHex);
            --diff-popover-fg: #636366;
            --diff-popover-border: rgba(0, 0, 0, 0.18);
        }
        @media (prefers-color-scheme: dark) {
            :root {
                --diff-popover-fg: #aeaeb2;
                --diff-popover-border: rgba(255, 255, 255, 0.18);
            }
        }
        * { box-sizing: border-box; }
        html {
            -webkit-text-size-adjust: 100%;
            text-size-adjust: 100%;
            font-size: 10pt;
            height: 100%;
            overflow: hidden;
        }
        html, body {
            margin: 0;
            padding: 0;
            background: #ffffff;
            color: #1d1d1f;
            font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif;
        }
        body {
            box-sizing: border-box;
            height: 100%;
            overflow-x: hidden;
            overflow-y: auto;
            overscroll-behavior: contain;
            padding: 14px 16px 18px;
            font-size: 1rem;
            line-height: 1.45;
            outline: none;
            -webkit-user-select: text;
            user-select: text;
        }
        body[data-interactive="true"] {
            cursor: text;
        }
        .framework-label {
            margin: 0 0 12px;
            font-size: 0.8rem;
            font-weight: 600;
            letter-spacing: 0.08em;
            color: var(--accent);
        }
        h1.recipe-title {
            margin: 0 0 8px;
            font-size: 1.45rem;
            font-weight: 700;
            line-height: 1.2;
        }
        h1, h2, h3 {
            margin: 0;
        }
        h2 {
            margin-top: 12px;
            margin-bottom: 6px;
            font-size: 1.12rem;
            font-weight: 600;
        }
        h3 {
            margin-top: 10px;
            margin-bottom: 4px;
            font-size: 1.02rem;
            font-weight: 600;
        }
        p {
            margin: 0 0 8px;
            color: #636366;
        }
        ul, ol {
            margin: 0 0 8px;
            padding-left: 16px;
        }
        li {
            margin-bottom: 4px;
        }
        li:last-child {
            margin-bottom: 0;
        }
        """

        if includesDiffStyles {
            rules += """

        .recipe-summary {
            margin: 0 0 8px;
            color: #636366;
        }
        .recipe-empty {
            margin: 0 0 8px;
            color: #aeaeb2;
            font-size: 0.95rem;
        }
        ul.recipe-diff-list {
            list-style: none;
            padding-left: 0;
            margin: 0 0 8px;
        }
        ul.recipe-diff-list > li {
            display: block;
            margin: 0 0 4px;
            padding: 0;
        }
        ul.recipe-diff-list > li.diff-unchanged {
            padding-left: 0;
        }
        ul.recipe-diff-list > li:last-child {
            margin-bottom: 0;
        }
        .diff-change-group {
            position: relative;
            list-style: none;
        }
        .diff-change-block {
            margin: 0 0 8px;
        }
        .diff-line.diff-review-anchor {
            position: relative;
        }
        .diff-change-group .diff-line {
            display: block;
            margin: 0 0 4px;
        }
        .diff-change-group .diff-line:last-of-type {
            margin-bottom: 0;
        }
        .diff-review-popover {
            display: inline-flex;
            position: absolute;
            right: 0;
            bottom: 0;
            transform: translateY(calc(50% + 0.5lh));
            z-index: 20;
            align-items: stretch;
            gap: 0;
            padding: 0;
            border-radius: 4px;
            border: 1px solid var(--diff-popover-border);
            background: #ffffff;
            color: var(--diff-popover-fg);
            overflow: hidden;
            pointer-events: auto;
            -webkit-user-select: none;
            user-select: none;
            -webkit-user-modify: read-only;
        }
        @media (prefers-color-scheme: dark) {
            .diff-review-popover {
                background: #2c2c2e;
            }
        }
        .diff-review-y,
        .diff-review-n {
            width: 22px;
            height: 16px;
            min-width: 22px;
            min-height: 16px;
            max-width: 22px;
            max-height: 16px;
            padding: 0;
            margin: 0;
            border: none;
            border-radius: 0;
            font: 600 0.62rem/1 -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
            color: var(--diff-popover-fg);
            background: transparent;
            cursor: pointer;
            flex: 0 0 auto;
            box-sizing: border-box;
            pointer-events: auto;
            -webkit-user-select: none;
            user-select: none;
            -webkit-appearance: none;
            appearance: none;
        }
        .diff-review-y {
            border-right: 1px solid var(--diff-popover-border);
        }
        .diff-review-y:hover,
        .diff-review-n:hover {
            background: transparent;
            color: var(--diff-popover-fg);
        }
        .diff-prefix {
            display: inline-block;
            width: 18px;
            margin-right: 6px;
            font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
            font-size: 0.92em;
            font-weight: 700;
            vertical-align: baseline;
            user-select: none;
            -webkit-user-select: none;
        }
        .diff-text {
            display: inline;
        }
        .diff-line.diff-addition,
        .diff-addition {
            color: #1b7f3b;
            background: rgba(27, 127, 59, 0.16);
            border-radius: 6px;
            padding: 2px 6px;
        }
        .diff-line.diff-addition .diff-prefix,
        .diff-addition .diff-prefix {
            color: #1b7f3b;
        }
        .diff-line.diff-removal,
        .diff-removal {
            color: #b42318;
            background: rgba(180, 35, 24, 0.14);
            border-radius: 6px;
            padding: 2px 6px;
            cursor: default;
        }
        .diff-line.diff-removal .diff-text,
        .diff-removal .diff-text {
            text-decoration: line-through;
            text-decoration-color: currentColor;
        }
        .diff-line.diff-removal .diff-prefix,
        .diff-removal .diff-prefix {
            color: #b42318;
        }
        h1.diff-line,
        p.diff-line {
            display: block;
        }
        """
        }

        return rules
    }
}
