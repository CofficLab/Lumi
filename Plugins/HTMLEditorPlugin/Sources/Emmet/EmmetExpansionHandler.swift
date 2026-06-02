import Foundation

/// Emmet Tab 键触发与冲突处理
///
/// 智能判断是否应展开 Emmet 缩写：
/// - 若光标前有有效缩写则展开
/// - 否则保留 Tab 缩进行为
public enum EmmetExpansionHandler {
    // MARK: - 公共接口

    /// 处理 Tab 键事件
    ///
    /// - Parameters:
    ///   - linePrefix: 当前行光标前的文本
    ///   - wordPrefix: 当前单词前缀（从最近的空白字符到光标位置）
    ///   - languageId: 当前语言标识
    /// - Returns: 如果应展开 Emmet，返回展开结果；否则返回 nil
    public static func handleTab(
        linePrefix: String,
        wordPrefix: String,
        languageId: String
    ) -> EmmetExpansion? {
        let word = wordPrefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty else { return nil }

        // 检查上下文是否允许 HTML Emmet
        guard EmmetConfig.isEnabled(at: .html) else { return nil }

        // 检查是否是有效的 Emmet 缩写
        guard EmmetEngine.isValidAbbreviation(word) else { return nil }

        // 检查是否是已知标签名（避免对简单标签名触发 Emmet）
        let isSimpleTag = HTMLKnowledgeBase.tags.contains { $0.name.lowercased() == word.lowercased() }
        if isSimpleTag {
            // 简单标签名不展开，但带类或 ID 的应该展开
            // 例如：div 不展开，但 div.container 应该展开
            return nil
        }

        // 尝试展开
        let syntax = EmmetConfig.syntaxMode(for: languageId)
        return EmmetEngine.expand(word, syntax: syntax)
    }

    /// 判断是否应该触发 Emmet 展开
    ///
    /// - Parameters:
    ///   - linePrefix: 当前行光标前的文本
    ///   - wordPrefix: 当前单词前缀
    /// - Returns: 如果应该触发 Emmet，返回 true
    public static func shouldExpand(
        linePrefix: String,
        wordPrefix: String
    ) -> Bool {
        let word = wordPrefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty else { return false }

        // 必须包含 Emmet 操作符
        let emmetOperators = CharacterSet(charactersIn: ".#>+*^[]{}()$@")
        if word.unicodeScalars.contains(where: { emmetOperators.contains($0) }) {
            return EmmetEngine.isValidAbbreviation(word)
        }

        // 检查是否为缩写模式（如 ul>li）
        if word.contains(">") || word.contains("+") {
            return true
        }

        return false
    }
}
