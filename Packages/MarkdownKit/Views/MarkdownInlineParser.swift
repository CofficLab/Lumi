import Foundation

/// 行内 Markdown 解析器。
///
/// 处理 Swift `AttributedString(markdown:)` 对 CJK 文本后紧跟标点开头强调
/// （如 `中文**“加粗”**`）解析失败的问题。
public enum MarkdownInlineParser {

    // MARK: - 公开方法

    public static func parse(_ text: String) -> AttributedString {
        if let attributed = try? AttributedString(
            markdown: text,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
        ), shouldUseNativeParseResult(attributed, originalText: text) {
            return attributed
        }

        return parseFallback(text)
    }

    // MARK: - 私有方法

    private static func parseFallback(_ text: String) -> AttributedString {
        var result = AttributedString()
        var index = text.startIndex

        while index < text.endIndex {
            guard let opening = text[index...].range(of: "**") else {
                result += AttributedString(String(text[index...]))
                break
            }

            if opening.lowerBound > index {
                result += AttributedString(String(text[index..<opening.lowerBound]))
            }

            let contentStart = opening.upperBound
            guard let closing = text[contentStart...].range(of: "**") else {
                result += AttributedString(String(text[opening.lowerBound...]))
                break
            }

            let emphasized = String(text[contentStart..<closing.lowerBound])
            if emphasized.isEmpty || emphasized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                result += AttributedString(String(text[opening.lowerBound..<closing.upperBound]))
            } else {
                var attributed = AttributedString(emphasized)
                attributed.inlinePresentationIntent = .stronglyEmphasized
                result += attributed
            }

            index = closing.upperBound
        }

        return result
    }

    private static func shouldUseNativeParseResult(
        _ attributed: AttributedString,
        originalText: String
    ) -> Bool {
        if !containsEmphasisDelimiter(originalText) {
            return true
        }
        if String(attributed.characters).contains("**") {
            return false
        }
        return containsInlinePresentationIntent(attributed)
    }

    private static func containsInlinePresentationIntent(_ attributed: AttributedString) -> Bool {
        attributed.runs.contains { run in
            run.inlinePresentationIntent != nil
        }
    }

    private static func containsEmphasisDelimiter(_ text: String) -> Bool {
        text.contains("**")
    }
}
