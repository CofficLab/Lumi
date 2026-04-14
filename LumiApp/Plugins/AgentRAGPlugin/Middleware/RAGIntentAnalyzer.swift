import Foundation
import MagicKit

// MARK: - RAG 意图分析器

/// RAG 意图分析器
///
/// 负责判断用户消息是否需要使用 RAG 检索。
///
/// ## 判断逻辑
/// 1. 检查是否包含中文高意图触发词
/// 2. 检查是否包含英文高意图触发词
/// 3. 检查是否包含文件或路径引用
/// 4. 检查是否包含代码意图标记
/// 5. 检查是否为问句且包含代码相关词汇
struct RAGIntentAnalyzer {

    // MARK: - 触发词配置

    /// 中文高意图触发词
    private static let ragTriggersZH = [
        "项目", "代码", "功能", "文件", "实现", "在哪", "怎么", "如何", "为什么", "报错", "错误",
        "修复", "定位", "模块", "接口", "逻辑", "流程", "类", "方法", "函数", "目录", "路径",
    ]

    /// 英文高意图触发词
    private static let ragTriggersEN = [
        "project", "code", "file", "files", "implementation", "implement", "where", "how", "why",
        "function", "method", "class", "module", "folder", "directory", "path", "api",
        "bug", "error", "issue", "fix", "refactor", "stack trace", "exception",
    ]

    /// 问句线索
    private static let questionMarkers = [
        "?", "？", "怎么", "如何", "为什么", "why", "how", "where", "what", "which", "can you", "could you",
    ]

    /// 与代码检索相关的语义线索
    private static let codeIntentMarkers = [
        "func ", "class ", "struct ", "enum ", "protocol ", "import ", "throws ", "return ",
        "def ", "function ", "interface ", "extends ", "namespace ", "package ", "```",
    ]

    private static let codeFileExtensions = [
        ".swift", ".m", ".mm", ".h", ".hpp", ".c", ".cc", ".cpp", ".js", ".ts", ".tsx", ".jsx",
        ".json", ".yaml", ".yml", ".toml", ".md", ".py", ".rb", ".go", ".rs", ".java", ".kt",
        ".sql", ".html", ".css", ".scss", ".xml", ".sh", ".zsh",
    ]

    // MARK: - 公共方法

    /// 判断是否应该使用 RAG 检索
    ///
    /// - Parameter message: 用户消息内容
    /// - Returns: 是否应该使用 RAG
    static func shouldUseRAG(for message: String) -> Bool {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let lowercased = trimmed.lowercased()

        // 检查中文触发词
        if ragTriggersZH.contains(where: { lowercased.contains($0) }) {
            return true
        }

        // 检查英文触发词
        if ragTriggersEN.contains(where: { lowercased.contains($0) }) {
            return true
        }

        // 检查文件或路径引用
        if hasFileOrPathReference(lowercased) {
            return true
        }

        // 检查代码意图标记
        if codeIntentMarkers.contains(where: { lowercased.contains($0) }) {
            return true
        }

        // 检查是否为问句且包含代码相关词汇
        let hasQuestion = questionMarkers.contains(where: { lowercased.contains($0) })
        if hasQuestion && containsCodeIntentWord(lowercased) {
            return true
        }

        return false
    }

    // MARK: - 私有辅助方法

    /// 检查是否包含文件或路径引用
    private static func hasFileOrPathReference(_ message: String) -> Bool {
        // 包含路径分隔符
        if message.contains("/") || message.contains("\\") {
            return true
        }

        // 包含代码文件扩展名
        return codeFileExtensions.contains(where: { message.contains($0) })
    }

    /// 检查是否包含代码意图词汇
    private static func containsCodeIntentWord(_ message: String) -> Bool {
        let intentWords = [
            "代码", "文件", "实现", "函数", "方法", "类", "模块", "接口", "错误", "报错",
            "code", "file", "implementation", "function", "method", "class", "module", "api", "error", "bug",
        ]
        return intentWords.contains(where: { message.contains($0) })
    }
}
