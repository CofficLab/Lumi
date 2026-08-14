import Combine
import Foundation

// MARK: - Prompt Suggestion Item

/// 点击提示词时可执行的声明式动作。
///
/// 由插件在 `LumiPromptSuggestion.action` 中声明，点击时由内核/UI 统一执行
/// （无需回到插件代码）。这是「插件动作能力」的载体：新增动作类型只需给本枚举加 case
/// 并在点击处处理。纯数据，`Sendable` 安全。
public enum LumiPromptAction: Equatable, Sendable {
    /// 激活指定 id 的视图容器（等价于 `kernel.workspace?.activateContainer(id:)`）。
    ///
    /// 常用于点击某插件的提示词后自动切换到该插件的工作面板。注意：若来源插件当前
    /// 禁用，点击流程会先启用它（含贡献重建，注册其容器）再执行本动作，确保目标容器
    /// 已存在。
    case activateViewContainer(_ id: String)

    /// 激活指定视图容器，并将其 rail 侧栏切换到指定 tab（等价于先
    /// `activateContainer(id:)` 再 `presentRailTab(id:for:)`）。
    ///
    /// rail tab 隶属于容器，因此需要同时指定容器 id 与 tab id。常用于点击提示词后
    /// 自动切换到某插件的容器并定位到其某个子面板（如多 tab 容器中的特定一项）。
    /// 若来源插件当前禁用，点击流程会先启用它（含贡献重建，注册其容器与 tab）再执行
    /// 本动作，确保目标容器与 tab 已存在。
    case activateRailTab(id: String, viewContainerID: String)
}

/// 聊天起始提示词项
///
/// 插件通过 `LumiPlugin.promptSuggestions(kernel:)` 贡献，由内核聚合后供空态等
/// UI 展示。点击提示词时通常把 `prompt` 写入输入框并发送；若声明了 `action`，会在
/// 发送前先执行该动作（如激活来源插件的视图容器）。
///
/// `order`、`pluginID`、`requiresEnable` 均由内核在聚合时盖戳，插件无需（也无法）
/// 通过初始化器指定：
/// - `order`：从所属插件的 `order` 自动继承。
/// - `pluginID`：记录该提示词来自哪个插件，便于点击时按需启用其来源插件。
/// - `requiresEnable`：来源插件当前是否未启用；为 `true` 时，UI 点击应先启用该插件
///   再执行动作与发送。
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

    /// 可选的点击动作（声明式，由内核执行）。`nil` 表示点击仅发送提示词。
    public let action: LumiPromptAction?

    /// 来源插件 ID（由内核盖戳）。`nil` 表示未被内核收集过。
    public var pluginID: String?

    /// 来源插件当前是否未启用（由内核盖戳）。为 `true` 时点击应先启用该插件。
    public var requiresEnable: Bool

    /// 公开初始化器（不包含内核盖戳字段）。
    ///
    /// - Parameters:
    ///   - id: 稳定唯一标识，建议带插件前缀（如 `"icon-designer.design"`）。
    ///   - title: 展示文案。
    ///   - prompt: 点击后注入输入框的真实提示词；传 `nil` 时回退为 `title`。
    ///   - systemImage: 可选 SF Symbol 图标名。
    ///   - action: 可选的点击动作（如激活视图容器）；传 `nil` 时点击仅发送提示词。
    public init(
        id: String,
        title: String,
        prompt: String? = nil,
        systemImage: String? = nil,
        action: LumiPromptAction? = nil
    ) {
        self.id = id
        self.order = 200  // 默认值，内核会覆盖
        self.title = title
        self.prompt = prompt ?? title
        self.systemImage = systemImage
        self.action = action
        self.pluginID = nil
        self.requiresEnable = false
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
