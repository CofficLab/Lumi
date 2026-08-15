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
    /// 若来源插件当前禁用，点击流程会先启用它（含贡献重建，注册其容器与 tab），
    /// 本动作确保目标容器与 tab 已存在。
    case activateRailTab(id: String, viewContainerID: String)

    /// 打开系统文件夹选择器，选中目录后作为项目添加并设为当前项目。
    ///
    /// 这是一个「终端动作」：执行后**不发送消息**。文件夹选择与落地由展示该
    /// 提示词的空态 UI 完成（经 `ProjectProviding.openProject(at:)` 统一处理），
    /// 因此宿主需在点击处接线选择器；未接线的宿主会忽略本动作。
    case pickProjectFolder

    /// 打开设置窗口并定位到指定标签页（发出 `.lumiOpenSettingsTab` 通知，
    /// 由宿主 `WindowMain` 开窗、`SettingsView` 切换标签）。
    ///
    /// 这是一个「终端动作」：执行后**不发送消息**。标签 id 即插件在
    /// `settingsTabItems(kernel:)` 中贡献的 `SettingsTabItem.id`。
    case openSettingsTab(id: String)
}

/// 聊天起始提示词项
///
/// 插件通过 `LumiPlugin.promptSuggestions(kernel:)` 贡献，由内核聚合后供空态等
/// UI 展示。点击提示词时通常把 `prompt` 写入输入框并发送；若声明了 `action`，会在
/// 发送前先执行该动作（如激活来源插件的视图容器）。
///
/// 提示词的项目可见性：控制其在空态 UI 中的展示条件。
public enum LumiPromptSuggestionVisibility: Equatable, Sendable {
    /// 总是展示（默认）。
    case always
    /// 仅在已选择项目时展示（提示词依赖项目上下文）。
    case onlyWithProject
    /// 仅在未选择项目时展示（如「添加项目」入口类动作）。
    case onlyWithoutProject
}

/// 提示词胶囊的视觉风格。
public enum LumiPromptSuggestionStyle: Equatable, Sendable {
    /// 常规提示词胶囊：实线描边 + 主题色浅底，点击发送消息。
    case standard
    /// 「添加型」动作胶囊：虚线描边、无底色，与提示词并列展示但视觉可区分。
    case additive
}

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

    /// 项目可见性：仅在满足条件时由空态 UI 展示。默认 `.always`。
    public let visibility: LumiPromptSuggestionVisibility

    /// 胶囊视觉风格（实线提示词 / 虚线添加型动作）。默认 `.standard`。
    public let style: LumiPromptSuggestionStyle

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
    ///   - visibility: 项目可见性，控制空态 UI 的展示条件，默认 `.always`。
    ///   - style: 胶囊视觉风格，默认 `.standard`。
    public init(
        id: String,
        title: String,
        prompt: String? = nil,
        systemImage: String? = nil,
        action: LumiPromptAction? = nil,
        visibility: LumiPromptSuggestionVisibility = .always,
        style: LumiPromptSuggestionStyle = .standard
    ) {
        self.id = id
        self.order = 200  // 默认值，内核会覆盖
        self.title = title
        self.prompt = prompt ?? title
        self.systemImage = systemImage
        self.action = action
        self.visibility = visibility
        self.style = style
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
