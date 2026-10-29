import Foundation

/// Markdown 代码块语言标签 → tree-sitter 语法 id 的映射。
///
/// 语言标签来自围栏代码块的信息串（```swift），LLM 输出的写法五花八门
/// （`Swift` / `js` / `sh` / `shell script`…），这里按常见别名归一化。
enum CodeHighlightLanguage {

    /// 语言标签（小写、已去空白）→ 语法 id
    static let grammarIdByAlias: [String: String] = [
        "swift": "swift",
        "javascript": "javascript",
        "js": "javascript",
        "jsx": "javascript",
        "mjs": "javascript",
        "cjs": "javascript",
        "typescript": "typescript",
        "ts": "typescript",
        "mts": "typescript",
        "cts": "typescript",
        "tsx": "tsx",
        "json": "json",
        "jsonc": "json",
        "markdown": "markdown",
        "md": "markdown",
        "python": "python",
        "py": "python",
        "bash": "bash",
        "sh": "bash",
        "shell": "bash",
        "zsh": "bash",
        "shellscript": "bash",
        "yaml": "yaml",
        "yml": "yaml",
    ]

    /// 解析语言标签 → 语法 id。
    ///
    /// - Returns: 受支持的语法 id；语言缺失或不支持时返回 `nil`（调用方降级为纯文本）。
    static func grammarId(for language: String?) -> String? {
        guard let language else { return nil }
        let key = language.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return nil }
        return grammarIdByAlias[key]
    }

    /// 受支持的语言标签（按字母序），用于展示与测试。
    static var supportedLanguageAliases: [String] {
        grammarIdByAlias.keys.sorted()
    }
}
