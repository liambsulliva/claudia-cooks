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
                html += "<li>\(plainTextHTML(item))</li>\n"
                continue
            }

            if let item = numberedItem(from: trimmed) {
                if !inList || listTag != "ol" {
                    closeList()
                    html += "<ol>\n"
                    inList = true
                    listTag = "ol"
                }
                html += "<li>\(plainTextHTML(item))</li>\n"
                continue
            }

            closeList()
            html += "<p>\(plainTextHTML(trimmed))</p>\n"
        }

        closeList()
        return html
    }

    private static func headingTag(for line: String) -> String? {
        if line.hasPrefix("### ") {
            let text = String(line.dropFirst(4))
            return "<h3>\(plainTextHTML(text))</h3>\n"
        }
        if line.hasPrefix("## ") {
            let text = String(line.dropFirst(3))
            return "<h2>\(plainTextHTML(text))</h2>\n"
        }
        if line.hasPrefix("# ") {
            let text = String(line.dropFirst(2))
            return "<h1>\(plainTextHTML(text))</h1>\n"
        }
        return nil
    }

    private static func plainTextHTML(_ text: String) -> String {
        escapeHTML(unescapeMarkdown(text))
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

    static func unescapeMarkdown(_ text: String) -> String {
        var unescaped = ""
        unescaped.reserveCapacity(text.count)

        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            if character == "\\" {
                let next = text.index(after: index)
                if next < text.endIndex {
                    unescaped.append(text[next])
                    index = text.index(after: next)
                    continue
                }
            }
            unescaped.append(character)
            index = text.index(after: index)
        }

        return unescaped
    }

    static func escapeMarkdown(_ text: String) -> String {
        var escaped = ""
        escaped.reserveCapacity(text.count)

        for character in text {
            switch character {
            case "\\", "`", "*", "_", "#", "+", "-", "!", "[", "]", "(", ")":
                escaped.append("\\")
                escaped.append(character)
            default:
                escaped.append(character)
            }
        }

        return escaped
    }
}
