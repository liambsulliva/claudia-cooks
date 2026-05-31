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
        let body = MarkdownToHTML.convert(markdown)
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
        \(editScript(framework: framework))
        </script>
        </body>
        </html>
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

    private static func stylesheet(framework: RecipeFramework) -> String {
        """
        :root {
            color-scheme: light;
            --accent: \(framework.htmlAccentHex);
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
    }
}
