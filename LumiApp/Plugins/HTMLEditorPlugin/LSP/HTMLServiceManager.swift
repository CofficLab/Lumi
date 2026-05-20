import Foundation

/// HTML 语言服务管理器
///
/// 管理 HTML 语言服务器的生命周期，提供基础补全和诊断。
///
/// 实现策略：
/// - 使用内置 HTML 字典作为快速响应层（零延迟）
/// - 可选接入外部 LSP（如 vscode-html-languageserver）作为增强层
@MainActor
final class HTMLServiceManager {
    /// 单例实例
    static let shared = HTMLServiceManager()

    /// 是否已初始化
    private var isInitialized = false

    /// HTML 语言服务器状态
    enum ServerState {
        case stopped
        case starting
        case running
        case error(String)
    }

    private(set) var serverState: ServerState = .stopped

    private init() {}

    // MARK: - 生命周期

    /// 初始化 HTML 语言服务
    func initialize() {
        guard !isInitialized else { return }
        isInitialized = true
        serverState = .running

        // 预加载 HTML 字典到内存
        _ = HTMLKnowledgeBase.tags
        _ = HTMLKnowledgeBase.globalAttributes
        _ = HTMLTreeSitterRegistration.languageDefinition
    }

    /// 停止 HTML 语言服务
    func shutdown() {
        isInitialized = false
        serverState = .stopped
    }

    // MARK: - 能力查询

    /// 检查是否支持 HTML 语言服务
    func isAvailable(for languageId: String) -> Bool {
        return HTMLKnowledgeBase.isSupported(languageId: languageId) && isInitialized
    }

    // MARK: - 补全

    /// 获取 HTML 补全建议
    ///
    /// - Parameters:
    ///   - prefix: 输入前缀
    ///   - tagName: 当前标签名（用于过滤属性）
    ///   - isInTag: 是否在标签名上下文中
    /// - Returns: 补全建议数组
    func provideCompletions(
        prefix: String,
        tagName: String? = nil,
        isInTag: Bool = false
    ) -> [EditorCompletionSuggestion] {
        if isInTag {
            // 在标签名上下文（如 `<d|`）
            return HTMLKnowledgeBase.tagSuggestions(prefix: prefix)
        } else if tagName != nil {
            // 在属性上下文（如 `<div c|`）
            return HTMLKnowledgeBase.attributeSuggestions(prefix: prefix, for: tagName)
        } else {
            // 通用上下文
            return HTMLKnowledgeBase.tagSuggestions(prefix: prefix)
        }
    }

    // MARK: - 悬浮

    /// 获取悬浮提示
    func provideHover(for symbol: String) -> String? {
        return HTMLKnowledgeBase.hoverMarkdown(for: symbol) ??
            ARIAAttributeDatabase.hoverMarkdown(for: symbol)
    }
}
