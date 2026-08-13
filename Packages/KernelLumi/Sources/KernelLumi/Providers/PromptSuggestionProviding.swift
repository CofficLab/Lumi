import Combine
import Foundation

// MARK: - Prompt Suggestion Item

/// 聊天起始提示词项
///
/// 插件通过 `LumiPlugin.promptSuggestions(kernel:)` 贡献，由内核聚合后供空态等
/// UI 展示。点击提示词时通常把 `prompt` 写入输入框并发送。
///
/// `order` 由内核从所属插件的 `order` 自动继承，无需手动指定。
@MainActor
public struct LumiPromptSuggestion: Identifiable, Sendable {
    public let id: String
    public var order: Int

    /// 展示文案（按钮标题）。
    public let title: String

    /// 点击后注入输入框的真实提示词。
    public let prompt: String

    /// 可选的 SF Symbol 图标名。
    public let systemImage: String?

    /// 公开初始化器（不包含 order）。
    ///
    /// - Parameters:
    ///   - id: 稳定唯一标识，建议带插件前缀（如 `"icon-designer.design"`）。
    ///   - title: 展示文案。
    ///   - prompt: 点击后注入输入框的真实提示词；传 `nil` 时回退为 `title`。
    ///   - systemImage: 可选 SF Symbol 图标名。
    public init(id: String, title: String, prompt: String? = nil, systemImage: String? = nil) {
        self.id = id
        self.order = 200  // 默认值，内核会覆盖
        self.title = title
        self.prompt = prompt ?? title
        self.systemImage = systemImage
    }
}

// MARK: - Prompt Suggestion Capability Protocol

/// 提示词聚合能力协议
///
/// 定义 LumiCore 需要的提示词聚合功能，由内核提供默认实现 `PromptSuggestionManager`。
/// 负责管理所有插件贡献的提示词注册、排序和查询。
///
/// `ObjectWillChangePublisher == ObservableObjectPublisher` 约束与
/// `WorkspaceProviding`/`ConversationManaging` 一致，用于让协议存在类型
/// （`any PromptSuggestionProviding`）的 `objectWillChange` 可被订阅，
/// 从而支持 SwiftUI 消费视图响应式刷新。
@MainActor
public protocol PromptSuggestionProviding: ObservableObject where ObjectWillChangePublisher == ObservableObjectPublisher {
    /// 所有已注册的提示词（按 `order` 排序；同 `order` 保持插件返回顺序）。
    var allPromptSuggestions: [LumiPromptSuggestion] { get }

    /// 注册一个提示词（按 `id` 去重，已存在则更新）。
    func registerPromptSuggestion(_ suggestion: LumiPromptSuggestion)

    /// 注销一个提示词。
    func unregisterPromptSuggestion(id: String)

    /// 清空全部贡献（全量重建时调用）。
    func clearAllContributions()
}
