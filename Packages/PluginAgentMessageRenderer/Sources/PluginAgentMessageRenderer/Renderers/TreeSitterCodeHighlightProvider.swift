import Foundation
import SwiftUI
import MarkdownKit
import CodeEditSourceEditor
import CodeEditLanguages
import SwiftTreeSitter

/// 基于 tree-sitter 的代码语法高亮提供者。
/// 将 Markdown 代码块的语言标签映射到 CodeLanguage，
/// 通过 tree-sitter 解析生成带颜色的 AttributedString。
public final class TreeSitterCodeHighlightProvider: CodeHighlightProviding, @unchecked Sendable {

    // MARK: - 属性

    /// 当前编辑器主题，用于将语法捕获类型映射到颜色
    private let editorTheme: EditorTheme

    // MARK: - 初始化

    public init(editorTheme: EditorTheme) {
        self.editorTheme = editorTheme
    }

    // MARK: - CodeHighlightProviding

    public var cacheIdentifier: String {
        "tree-sitter:\(String(describing: editorTheme))"
    }

    public func highlight(code: String, language: String?) -> AttributedString? {
        guard let codeLanguage = resolveCodeLanguage(language) else {
            return nil
        }

        let nsCode = code as NSString
        let fullRange = NSRange(location: 0, length: nsCode.length)

        // 获取 tree-sitter 语言和查询
        guard let tsLanguage = codeLanguage.language,
              let query = TreeSitterModel.shared.query(for: codeLanguage.id) else {
            return nil
        }

        // 解析代码
        let parser = Parser()
        do {
            try parser.setLanguage(tsLanguage)
        } catch {
            return nil
        }

        guard let tree = parser.parse(code) else { return nil }
        guard let rootNode = tree.rootNode else { return nil }

        // 执行高亮查询
        let cursor = query.execute(node: rootNode, in: tree)
        cursor.setRange(fullRange)
        cursor.matchLimit = 256

        let textProvider: SwiftTreeSitter.Predicate.TextProvider = { range, _ in
            return nsCode.substring(with: range)
        }

        // 收集高亮范围
        let highlights = resolveHighlights(cursor: cursor, textProvider: textProvider, fullRange: fullRange)

        guard !highlights.isEmpty else { return nil }

        // 构建 NSMutableAttributedString 并应用颜色
        let defaultColor = editorTheme.text.color
        let mutableAttrString = NSMutableAttributedString(
            string: code,
            attributes: [
                .foregroundColor: defaultColor,
            ]
        )

        for highlight in highlights {
            let color = editorTheme.colorForCapture(highlight.capture)
            mutableAttrString.addAttribute(
                .foregroundColor,
                value: color,
                range: highlight.range
            )
        }

        // 转换为 AttributedString
        if let result = try? AttributedString(mutableAttrString, including: \.appKit) {
            return result
        }

        return nil
    }

    // MARK: - Private

    /// 解析高亮查询结果
    private func resolveHighlights(
        cursor: QueryCursor,
        textProvider: @escaping SwiftTreeSitter.Predicate.TextProvider,
        fullRange: NSRange
    ) -> [(range: NSRange, capture: CaptureName)] {
        let resolved = cursor.resolve(with: .init(textProvider: textProvider))
        return resolved
            .flatMap { $0.captures }
            .reversed()
            .compactMap { capture -> (range: NSRange, capture: CaptureName)? in
                guard let captureName = CaptureName.fromString(capture.name) else { return nil }
                let range = capture.range
                let intersection = range.intersection(fullRange) ?? .zero
                guard intersection.length > 0 else { return nil }
                return (range: intersection, capture: captureName)
            }
            .reversed()
    }

    /// 将 Markdown 代码块的语言标签映射到 CodeLanguage
    private func resolveCodeLanguage(_ language: String?) -> CodeLanguage? {
        guard let language, !language.isEmpty else { return nil }

        // 构造一个伪 URL 利用 CodeLanguage 的扩展名检测
        let fakeURL = URL(fileURLWithPath: "dummy.\(language.lowercased())")
        let detected = CodeLanguage.detectLanguageFrom(url: fakeURL)

        // detectLanguageFrom 在无法识别时返回 .default，排除掉
        if detected.id == .plainText {
            return nil
        }

        return detected
    }
}

// MARK: - EditorTheme Color Extension

extension EditorTheme {
    /// 将 CaptureName 映射到颜色
    public func colorForCapture(_ capture: CaptureName) -> NSColor {
        switch capture {
        case .include, .constructor, .keyword, .boolean, .variableBuiltin,
                .keywordReturn, .keywordFunction, .repeat, .conditional, .tag:
            return keywords.color
        case .comment:
            return comments.color
        case .variable, .property:
            return variables.color
        case .function, .method:
            return commands.color
        case .number, .float:
            return numbers.color
        case .string:
            return strings.color
        case .type:
            return types.color
        case .parameter:
            return variables.color
        case .typeAlternate:
            return attributes.color
        }
    }
}
