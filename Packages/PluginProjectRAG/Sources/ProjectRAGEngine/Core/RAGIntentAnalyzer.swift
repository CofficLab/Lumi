import Foundation

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
public struct RAGIntentAnalyzer {

    // MARK: - 触发词配置

    /// 中文高意图触发词
    private static let ragTriggersZH = [
        "项目", "代码", "功能", "文件", "实现", "在哪", "怎么", "如何", "为什么", "报错", "错误",
        "修复", "定位", "模块", "接口", "逻辑", "流程", "类", "方法", "函数", "目录", "路径",
    ]

    /// 英文高意图触发词
    private static let ragTriggersEN = [
        "project", "code", "file", "files", "implementation", "implement",
        "function", "method", "class", "module", "folder", "directory", "path", "api",
        "bug", "error", "issue", "fix", "refactor", "stack trace", "exception",
    ]

    /// 问句线索
    private static let questionMarkers = [
        "?", "？", "怎么", "如何", "为什么", "在哪", "why", "how", "where", "what", "which", "can you", "could you",
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
    public static func shouldUseRAG(for message: String) -> Bool {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let lowercased = trimmed.lowercased()

        // 检查中文触发词
        if ragTriggersZH.contains(where: { lowercased.contains($0) }) {
            return true
        }

        // 检查英文触发词。使用单词边界，避免 "fix" 命中 "prefix" 之类的普通文本。
        if ragTriggersEN.contains(where: { containsWholeEnglishTrigger($0, in: lowercased) }) {
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

    /// 判断是否应该「自动注入」检索上下文（比 `shouldUseRAG` 严格得多）。
    ///
    /// `shouldUseRAG` 的问题触发词表很宽（项目/功能/怎么…），几乎任何中文问句都命中，
    /// 适合工具侧自行决定是否检索；但每轮自动注入会污染上下文，必须收窄到高置信场景：
    /// 1. 含文件/路径引用；
    /// 2. 含代码意图标记（func/class/``` 等）；
    /// 3. 问句 ∧（含标识符样词 ∨ 含实现/设计/架构/调用/依赖等领域词）。
    /// 「今天天气怎么样」「帮我写周报」不再触发自动注入。
    public static func shouldAutoInject(for message: String) -> Bool {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let lowercased = trimmed.lowercased()

        if hasFileOrPathReference(lowercased) { return true }
        if codeIntentMarkers.contains(where: { lowercased.contains($0) }) { return true }

        let hasQuestion = questionMarkers.contains(where: { lowercased.contains($0) })
        guard hasQuestion else { return false }

        if containsCodeSymbol(trimmed) { return true }

        let designWords = [
            "实现", "设计", "架构", "调用", "依赖",
            "design", "architecture", "implement", "invoke", "dependency", "call graph",
        ]
        return designWords.contains(where: { lowercased.contains($0) })
    }

    // MARK: - 私有辅助方法

    /// 是否含「标识符样词」：字母/下划线开头、长度 ≥ 3，且带内部大写、下划线或数字
    /// （CamelCase / snake_case / 带数字的符号）。借此排除 how/are/you/today 这类普通英文词，
    /// 避免英文闲聊问句被误判为代码问题。
    private static func containsCodeSymbol(_ message: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: "[A-Za-z_][A-Za-z0-9_]{2,}") else {
            return false
        }
        let range = NSRange(location: 0, length: (message as NSString).length)
        for match in regex.matches(in: message, range: range) {
            guard let tokenRange = Range(match.range, in: message) else { continue }
            let token = String(message[tokenRange])
            let hasInternalUppercase = token.dropFirst().contains { $0.isUppercase }
            if hasInternalUppercase || token.contains("_") || token.contains(where: { $0.isNumber }) {
                return true
            }
        }
        return false
    }

    private static func containsWholeEnglishTrigger(_ trigger: String, in message: String) -> Bool {
        let escapedTrigger = NSRegularExpression.escapedPattern(for: trigger)
        let pattern = "(?<![A-Za-z0-9])\(escapedTrigger)(?![A-Za-z0-9])"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(location: 0, length: (message as NSString).length)
        return regex.firstMatch(in: message, range: range) != nil
    }

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
