//
//  MarkdownToHTML.swift
//  claudia-cooks
//

import Foundation

enum MarkdownToHTML {
    static func convert(_ markdown: String) -> String {
        var html = ""
        var inList = false
        var listTag = "ul"

        func closeList() {
            guard inList else {
                return
            }
            html += "</\(listTag)>\n"
            inList = false
        }

        for line in markdown.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                closeList()
                continue
            }

            if trimmed.hasPrefix("<") {
                closeList()
                html += "\(line)\n"
                continue
            }

            if let heading = headingTag(for: trimmed) {
                closeList()
                html += heading
                continue
            }

            if let item = bulletItem(from: trimmed) {
                if !inList || listTag != "ul" {
                    closeList()
                    html += "<ul>\n"
                    inList = true
                    listTag = "ul"
                }
                html += "<li>\(escapeHTML(item))</li>\n"
                continue
            }

            if let item = numberedItem(from: trimmed) {
                if !inList || listTag != "ol" {
                    closeList()
                    html += "<ol>\n"
                    inList = true
                    listTag = "ol"
                }
                html += "<li>\(escapeHTML(item))</li>\n"
                continue
            }

            closeList()
            html += "<p>\(escapeHTML(trimmed))</p>\n"
        }

        closeList()
        return html
    }

    private static func headingTag(for line: String) -> String? {
        if line.hasPrefix("### ") {
            let text = String(line.dropFirst(4))
            return "<h3>\(escapeHTML(text))</h3>\n"
        }
        if line.hasPrefix("## ") {
            let text = String(line.dropFirst(3))
            return "<h2>\(escapeHTML(text))</h2>\n"
        }
        if line.hasPrefix("# ") {
            let text = String(line.dropFirst(2))
            return "<h1>\(escapeHTML(text))</h1>\n"
        }
        return nil
    }

    private static func bulletItem(from line: String) -> String? {
        if line.hasPrefix("- ") {
            return String(line.dropFirst(2))
        }
        if line.hasPrefix("* ") {
            return String(line.dropFirst(2))
        }
        return nil
    }

    private static func numberedItem(from line: String) -> String? {
        guard let dotIndex = line.firstIndex(of: ".") else {
            return nil
        }

        let prefix = line[..<dotIndex]
        guard !prefix.isEmpty, prefix.allSatisfy(\.isNumber) else {
            return nil
        }

        let remainderStart = line.index(after: dotIndex)
        guard remainderStart < line.endIndex, line[remainderStart] == " " else {
            return nil
        }

        return String(line[line.index(after: remainderStart)...])
    }

    static func escapeHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    static func escapeMarkdown(_ text: String) -> String {
        var escaped = ""
        escaped.reserveCapacity(text.count)

        for character in text {
            switch character {
            case "\\", "`", "*", "_", "#", "+", "-", ".", "!", "[", "]", "(", ")":
                escaped.append("\\")
                escaped.append(character)
            default:
                escaped.append(character)
            }
        }

        return escaped
    }
}
