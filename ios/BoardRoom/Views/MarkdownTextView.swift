import SwiftUI

struct MarkdownTextView: View {
    let content: String
    let textColor: Color

    init(content: String, textColor: Color = AppTheme.textPrimary) {
        self.content = content
        self.textColor = textColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(parseBlocks().enumerated()), id: \.offset) { _, block in
                renderBlock(block)
            }
        }
    }

    // MARK: - Block Types

    private enum MarkdownBlock {
        case heading(level: Int, text: String)
        case codeBlock(language: String?, code: String)
        case bulletList(items: [String])
        case numberedList(items: [String])
        case paragraph(text: String)
    }

    // MARK: - Parser

    private func parseBlocks() -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        let lines = content.components(separatedBy: "\n")
        var i = 0

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Code block
            if trimmed.hasPrefix("```") {
                let language = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                i += 1
                while i < lines.count {
                    if lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                        break
                    }
                    codeLines.append(lines[i])
                    i += 1
                }
                blocks.append(.codeBlock(
                    language: language.isEmpty ? nil : language,
                    code: codeLines.joined(separator: "\n")
                ))
                i += 1
                continue
            }

            // Heading
            if trimmed.hasPrefix("###") {
                let text = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                blocks.append(.heading(level: 3, text: text))
                i += 1
                continue
            }
            if trimmed.hasPrefix("##") {
                let text = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                blocks.append(.heading(level: 2, text: text))
                i += 1
                continue
            }
            if trimmed.hasPrefix("# ") {
                let text = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                blocks.append(.heading(level: 1, text: text))
                i += 1
                continue
            }

            // Bullet list
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("• ") {
                var items: [String] = []
                while i < lines.count {
                    let t = lines[i].trimmingCharacters(in: .whitespaces)
                    if t.hasPrefix("- ") || t.hasPrefix("* ") || t.hasPrefix("• ") {
                        items.append(String(t.dropFirst(2)).trimmingCharacters(in: .whitespaces))
                        i += 1
                    } else {
                        break
                    }
                }
                blocks.append(.bulletList(items: items))
                continue
            }

            // Numbered list
            if let _ = trimmed.range(of: #"^\d+[\.\)]\s"#, options: .regularExpression) {
                var items: [String] = []
                while i < lines.count {
                    let t = lines[i].trimmingCharacters(in: .whitespaces)
                    if let range = t.range(of: #"^\d+[\.\)]\s"#, options: .regularExpression) {
                        items.append(String(t[range.upperBound...]).trimmingCharacters(in: .whitespaces))
                        i += 1
                    } else {
                        break
                    }
                }
                blocks.append(.numberedList(items: items))
                continue
            }

            // Empty line - skip
            if trimmed.isEmpty {
                i += 1
                continue
            }

            // Paragraph - collect consecutive non-special lines
            var paraLines: [String] = []
            while i < lines.count {
                let t = lines[i].trimmingCharacters(in: .whitespaces)
                if t.isEmpty || t.hasPrefix("#") || t.hasPrefix("```") ||
                   t.hasPrefix("- ") || t.hasPrefix("* ") || t.hasPrefix("• ") ||
                   t.range(of: #"^\d+[\.\)]\s"#, options: .regularExpression) != nil {
                    break
                }
                paraLines.append(lines[i])
                i += 1
            }
            if !paraLines.isEmpty {
                blocks.append(.paragraph(text: paraLines.joined(separator: " ")))
            }
        }

        return blocks
    }

    // MARK: - Renderers

    @ViewBuilder
    private func renderBlock(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            renderInlineMarkdown(text)
                .font(headingFont(level: level))
                .foregroundColor(AppTheme.gold)
                .padding(.top, level == 1 ? 4 : 2)

        case .codeBlock(let language, let code):
            VStack(alignment: .leading, spacing: 4) {
                if let lang = language, !lang.isEmpty {
                    Text(lang)
                        .font(.caption2)
                        .foregroundColor(AppTheme.textMuted)
                        .padding(.horizontal, 8)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(code)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(Color(hex: "E0E0E0"))
                        .padding(10)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: "1E1E1E"))
            .cornerRadius(8)

        case .bulletList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                            .foregroundColor(AppTheme.gold)
                            .font(.body)
                        renderInlineMarkdown(item)
                            .font(.body)
                            .foregroundColor(textColor)
                    }
                }
            }

        case .numberedList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 6) {
                        Text("\(index + 1).")
                            .foregroundColor(AppTheme.gold)
                            .font(.body)
                            .frame(width: 22, alignment: .trailing)
                        renderInlineMarkdown(item)
                            .font(.body)
                            .foregroundColor(textColor)
                    }
                }
            }

        case .paragraph(let text):
            renderInlineMarkdown(text)
                .font(.body)
                .foregroundColor(textColor)
        }
    }

    private func renderInlineMarkdown(_ text: String) -> Text {
        if let attributed = try? AttributedString(
            markdown: text,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
        ) {
            return Text(attributed)
        } else {
            return Text(text)
        }
    }

    private func headingFont(level: Int) -> Font {
        switch level {
        case 1: return .system(size: 20, weight: .bold)
        case 2: return .system(size: 17, weight: .bold)
        default: return .system(size: 15, weight: .semibold)
        }
    }
}
