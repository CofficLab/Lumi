import SwiftUI

// MARK: - PreferOuterScroll

private struct PreferOuterScrollKey: EnvironmentKey {
    static let defaultValue = false
}

public extension EnvironmentValues {
    /// When true, markdown and text renderers avoid nested scroll views and let the outer container own scrolling.
    var preferOuterScroll: Bool {
        get { self[PreferOuterScrollKey.self] }
        set { self[PreferOuterScrollKey.self] = newValue }
    }
}

// MARK: - Code Highlighting

/// 代码语法高亮提供者协议。
/// MarkdownKit 通过此协议请求语法高亮，具体实现由应用层注入，
/// 保持 MarkdownKit 不依赖特定的语法分析引擎。
public protocol CodeHighlightProviding: Sendable {
    /// 对代码进行语法高亮，返回带颜色的 AttributedString。
    ///
    /// - Parameters:
    ///   - code: 源代码文本
    ///   - language: 语言标识（来自 Markdown 代码块的 language 标签，如 `"swift"`、`"python"`）
    /// - Returns: 带语法高亮颜色的 AttributedString；返回 `nil` 表示降级为纯文本
    func highlight(code: String, language: String?) -> AttributedString?
}

private struct CodeHighlightProviderKey: EnvironmentKey {
    static let defaultValue: (any CodeHighlightProviding)? = nil
}

public extension EnvironmentValues {
    /// 代码语法高亮提供者，由应用层注入。
    /// 为 `nil` 时代码块以纯文本渲染（无语法着色）。
    var codeHighlightProvider: (any CodeHighlightProviding)? {
        get { self[CodeHighlightProviderKey.self] }
        set { self[CodeHighlightProviderKey.self] = newValue }
    }
}
