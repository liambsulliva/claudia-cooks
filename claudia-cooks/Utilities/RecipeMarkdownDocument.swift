//
//  RecipeMarkdownDocument.swift
//  claudia-cooks
//

import Foundation

enum RecipeMarkdownDocument {
    static func html(
        markdown: String,
        framework: RecipeFramework,
        clickedBadgeIDs: Set<String> = [],
        isInteractive: Bool = true
    ) -> String {
        let body = applyClickedBadgeState(
            to: MarkdownToHTML.convert(markdown),
            clickedBadgeIDs: clickedBadgeIDs
        )
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="color-scheme" content="light">
        <style>
        \(stylesheet(framework: framework))
        </style>
        </head>
        <body
            data-interactive="\(isInteractive ? "true" : "false")"
            contenteditable="\(isInteractive ? "true" : "false")"
            spellcheck="true"
        >
        \(body)
        <script>
        \(badgeScript)
        \(editScript(framework: framework))
        </script>
        </body>
        </html>
        """
    }

    private static func applyClickedBadgeState(to html: String, clickedBadgeIDs: Set<String>) -> String {
        guard !clickedBadgeIDs.isEmpty else {
            return html
        }

        var updated = html
        for badgeID in clickedBadgeIDs {
            let escapedID = MarkdownToHTML.escapeHTML(badgeID)
            updated = updated.replacingOccurrences(
                of: "data-badge-row-id=\"\(escapedID)\"",
                with: "data-badge-row-id=\"\(escapedID)\" data-clicked=\"true\""
            )
            updated = updated.replacingOccurrences(
                of: "data-badge-id=\"\(escapedID)\" aria-pressed=\"false\"",
                with: "data-badge-id=\"\(escapedID)\" aria-pressed=\"true\""
            )
        }
        return updated
    }

    private static var badgeScript: String {
        """
        (function() {
            if (document.body.dataset.interactive !== 'true') {
                return;
            }

            function postToggle(button) {
                var id = button.dataset.badgeId;
                if (!id) {
                    return;
                }
                var isClicked = button.getAttribute('aria-pressed') === 'true';
                window.webkit.messageHandlers.badgeClick.postMessage({
                    id: id,
                    isClicked: !isClicked
                });
            }

            document.querySelectorAll('.recipe-badge').forEach(function(button) {
                button.contentEditable = 'false';
                button.addEventListener('click', function(event) {
                    event.preventDefault();
                    event.stopPropagation();
                    postToggle(button);
                });
            });
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
                var badgeText = item.querySelector('.badge-text');
                return cleanText((badgeText || item).innerText || item.textContent || '');
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

    private static func stylesheet(framework: RecipeFramework) -> String {
        """
        :root {
            color-scheme: light;
            --accent: \(framework.htmlAccentHex);
        }
        * { box-sizing: border-box; }
        html, body {
            margin: 0;
            padding: 0;
            overflow: hidden;
            background: #ffffff;
            color: #1d1d1f;
            font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif;
        }
        body {
            padding: 18px 20px 24px;
            font-size: 12px;
            line-height: 1.45;
            outline: none;
            -webkit-user-select: text;
            user-select: text;
        }
        body[data-interactive="true"] {
            cursor: text;
        }
        .framework-label {
            margin: 0 0 18px;
            font-size: 11px;
            font-weight: 600;
            letter-spacing: 0.08em;
            color: var(--accent);
        }
        h1.recipe-title {
            margin: 0 0 12px;
            font-size: 24px;
            font-weight: 700;
            line-height: 1.15;
        }
        h1, h2, h3 {
            margin: 0;
        }
        h2 {
            margin-top: 16px;
            margin-bottom: 8px;
            font-size: 15px;
            font-weight: 600;
        }
        h3 {
            margin-top: 12px;
            margin-bottom: 6px;
            font-size: 13px;
            font-weight: 600;
        }
        p {
            margin: 0 0 10px;
            color: #636366;
        }
        ul, ol {
            margin: 0 0 10px;
            padding-left: 18px;
        }
        ul.badge-list {
            list-style: none;
            padding: 0;
            margin: 0 0 10px;
        }
        li.badge-row {
            display: flex;
            align-items: flex-start;
            gap: 8px;
            margin-bottom: 6px;
        }
        li.badge-row:last-child {
            margin-bottom: 0;
        }
        li.badge-row[data-clicked="true"] .badge-text {
            color: #8e8e93;
            text-decoration: line-through;
        }
        button.recipe-badge {
            flex: 0 0 auto;
            margin-top: 1px;
            padding: 2px 8px;
            border-radius: 999px;
            border: 1px solid color-mix(in srgb, var(--accent) 35%, #d1d1d6);
            background: #f5f5f7;
            color: var(--accent);
            font-size: 10px;
            font-weight: 600;
            line-height: 1.2;
            cursor: pointer;
            -webkit-user-select: none;
            user-select: none;
        }
        button.recipe-badge[aria-pressed="true"] {
            background: var(--accent);
            border-color: var(--accent);
            color: #ffffff;
        }
        span.badge-text {
            flex: 1 1 auto;
            color: #1d1d1f;
        }
        li {
            margin-bottom: 5px;
        }
        li:last-child {
            margin-bottom: 0;
        }
        """
    }
}
