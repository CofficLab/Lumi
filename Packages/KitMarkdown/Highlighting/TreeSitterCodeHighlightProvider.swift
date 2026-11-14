import Foundation
import SwiftTreeSitter
import SwiftUI
import TreeSitterBash
import TreeSitterJavaScript
import TreeSitterJSON
import TreeSitterMarkdown
import TreeSitterPython
import TreeSitterSwift
import TreeSitterTSX
import TreeSitterTypeScript
import TreeSitterYAML

/// 基于 tree-sitter 的代码块语法高亮提供者。
///
/// Markdown 渲染树通过 `\.codeHighlightProvider` 环境变量拿到本实现，
/// `HighlightedCodeView` 用它把代码块染成带颜色的 `AttributedString`。
/// 语言不受支持（或语法缺失）时返回 `nil`，由调用方降级为纯文本。
public final class TreeSitterCodeHighlightProvider: CodeHighlightProviding, @unchecked Sendable {

    private let palette: CodeHighlightPalette

    init(palette: CodeHighlightPalette) {
        self.palette = palette
    }

    /// 按外观创建高亮器。
    public static func make(for colorScheme: ColorScheme) -> TreeSitterCodeHighlightProvider {
        colorScheme == .dark ? sharedDark : sharedLight
    }

    /// 共享实例（每种外观一个），避免每次渲染都新建。
    public static func shared(for colorScheme: ColorScheme) -> TreeSitterCodeHighlightProvider {
        colorScheme == .dark ? sharedDark : sharedLight
    }

    private static let sharedLight = TreeSitterCodeHighlightProvider(palette: .light)
    private static let sharedDark = TreeSitterCodeHighlightProvider(palette: .dark)

    public var cacheIdentifier: String {
        "tree-sitter-v1:\(palette.identifier)"
    }

    /// 受支持的语言标签（用于展示与测试）。
    public static var supportedLanguageAliases: [String] {
        CodeHighlightLanguage.supportedLanguageAliases
    }

    // MARK: - 高亮

    public func highlight(code: String, language: String?) -> AttributedString? {
        guard !code.isEmpty,
              let grammarId = CodeHighlightLanguage.grammarId(for: language),
              let treeSitterLanguage = Self.treeSitterLanguage(for: grammarId),
              let query = HighlightQueryCache.shared.query(for: grammarId, language: treeSitterLanguage)
        else { return nil }

        let parser = Parser()
        do {
            try parser.setLanguage(treeSitterLanguage)
        } catch {
            return nil
        }
        guard let tree = parser.parse(code), let rootNode = tree.rootNode else { return nil }

        var attributed = AttributedString(code)

        let cursor = query.execute(node: rootNode, in: tree)
        cursor.matchLimit = 512

        while let match = cursor.next() {
            for capture in match.captures {
                guard let name = capture.name,
                      let color = palette.color(forCapture: name)
                else { continue }

                guard let range = Self.attributedRange(
                    in: attributed,
                    source: code,
                    location: capture.range.location,
                    length: capture.range.length
                ) else { continue }

                attributed[range].foregroundColor = color
            }
        }

        return attributed
    }

    // MARK: - 偏移换算

    /// 把 tree-sitter 的捕获范围换算成 `AttributedString` 的字符范围。
    ///
    /// 关键点：**偏移单位取决于解析时使用的字节编码**。
    /// `SwiftTreeSitter.Parser.parse(_ string:)` 内部以 UTF-16LE 喂给
    /// tree-sitter（见 `Parser.parse(_:)` 里的 `TSInputEncodingUTF16LE`），
    /// 因此 `capture.range.location/length` 是 **UTF-16 code unit** 偏移，
    /// 不是 UTF-8 字节偏移。
    ///
    /// 纯 ASCII 代码两种单位恰好相同，所以问题只在包含非 ASCII 字符
    /// （例如中文注释）时暴露：偏移量偏小，捕获范围整体前移错位，
    /// 表现为注释被切成碎片、相邻语法着色串位。
    ///
    /// 这里按 UTF-16 偏移换算，保证与解析端编码一致。
    private static func attributedRange(
        in attributed: AttributedString,
        source: String,
        location: Int,
        length: Int
    ) -> Range<AttributedString.Index>? {
        guard location >= 0, length >= 0 else { return nil }

        let utf16 = source.utf16
        guard location + length <= utf16.count else { return nil }

        let lower = utf16.index(utf16.startIndex, offsetBy: location)
        let upper = utf16.index(utf16.startIndex, offsetBy: location + length)

        return Range(lower..<upper, in: attributed)
    }

    // MARK: - 语法

    /// 语法 id → tree-sitter 语言。
    private static func treeSitterLanguage(for grammarId: String) -> Language? {
        switch grammarId {
        case "swift": return Language(language: tree_sitter_swift())
        case "javascript": return Language(language: tree_sitter_javascript())
        case "typescript": return Language(language: tree_sitter_typescript())
        case "tsx": return Language(language: tree_sitter_tsx())
        case "json": return Language(language: tree_sitter_json())
        case "markdown": return Language(language: tree_sitter_markdown())
        case "python": return Language(language: tree_sitter_python())
        case "bash": return Language(language: tree_sitter_bash())
        case "yaml": return Language(language: tree_sitter_yaml())
        default: return nil
        }
    }
}

// MARK: - 查询缓存

/// tree-sitter 高亮查询缓存。
///
/// 查询的解析成本不高但不为零，且结果只取决于语法 id，缓存后可以跨消息复用。
/// 与 `CodeHighlightCache` 同构：锁保护，命中即返回。
private final class HighlightQueryCache: @unchecked Sendable {
    static let shared = HighlightQueryCache()

    private let lock = NSLock()
    private var queries: [String: Query] = [:]

    private init() {}

    func query(for grammarId: String, language: Language) -> Query? {
        lock.lock()
        let cached = queries[grammarId]
        lock.unlock()
        if let cached { return cached }

        guard let url = Self.queryURL(for: grammarId),
              let data = try? Data(contentsOf: url),
              let query = try? Query(language: language, data: data)
        else { return nil }

        lock.lock()
        queries[grammarId] = query
        lock.unlock()
        return query
    }

    /// 高亮查询文件位置（随包资源：`Resources/tree-sitter-<id>/highlights.scm`）。
    private static func queryURL(for grammarId: String) -> URL? {
        let folder = "tree-sitter-\(grammarId)"
        guard let resourceURL = Bundle.module.resourceURL else { return nil }
        let candidates = [
            resourceURL.appendingPathComponent("\(folder)/highlights.scm"),
            resourceURL.appendingPathComponent("Resources/\(folder)/highlights.scm"),
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }
}
