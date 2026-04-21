import SwiftUI

/// 悬浮提示气泡视图
/// 渲染 Markdown 格式的 LSP hover 内容，支持代码块、分隔线等
struct HoverPopoverView: View {
    let markdownText: String

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                let sections = parseSections(from: markdownText)
                ForEach(Array(sections.enumerated()), id: \.offset) { index, section in
                    if index > 0 {
                        Divider()
                            .padding(.vertical, 6)
                    }
                    hoverSectionView(section)
                }
            }
            .padding(10)
        }
        .frame(maxHeight: 300)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Section Parsing

    private enum HoverSection {
        case codeBlock(String, language: String)
        case plainText(String)
    }

    private func parseSections(from text: String) -> [HoverSection] {
        var sections: [HoverSection] = []
        let components = text.components(separatedBy: "\n\n---\n\n")

        for component in components {
            let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            // 检查是否是围栏代码块
            if trimmed.hasPrefix("```") {
                let lines = trimmed.components(separatedBy: .newlines)
                if lines.count >= 2 {
                    let firstLine = lines[0]
                    let language = String(firstLine.dropFirst(3).trimmingCharacters(in: .whitespaces))
                    let codeLines = lines.dropFirst().dropLast()
                    let code = codeLines.joined(separator: "\n")
                    if !code.isEmpty {
                        sections.append(.codeBlock(code, language: language))
                        continue
                    }
                }
            }

            sections.append(.plainText(trimmed))
        }

        return sections
    }

    @ViewBuilder
    private func hoverSectionView(_ section: HoverSection) -> some View {
        switch section {
        case .codeBlock(let code, let language):
            codeBlockView(code: code, language: language)
        case .plainText(let text):
            plainTextView(text: text)
        }
    }

    @ViewBuilder
    private func codeBlockView(code: String, language: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if !language.isEmpty {
                Text(language)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(AppUI.Color.semantic.textTertiary)
            }
            Text(code)
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(8)
                .multilineTextAlignment(.leading)
        }
    }

    @ViewBuilder
    private func plainTextView(text: String) -> some View {
        let attributed = hoverAttributedText(from: text)
        Text(attributed)
            .font(.system(size: 12))
            .textSelection(.enabled)
            .lineLimit(10)
            .multilineTextAlignment(.leading)
    }

    private func hoverAttributedText(from markdown: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        if let attributed = try? AttributedString(markdown: markdown, options: options) {
            return attributed
        }
        return AttributedString(markdown)
    }
}
