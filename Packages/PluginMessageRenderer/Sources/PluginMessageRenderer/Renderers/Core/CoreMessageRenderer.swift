import Foundation
import ProviderConversation
import ProviderMessage
import ProviderMessageRendering
import SwiftUI

/// 核心消息渲染器：接管**整条消息**，决定「这条消息画成什么样」。
///
/// 与 `ToolCallRowRenderer` 的分工：后者只替换 assistant 消息内部的
/// 单个 ToolCall 行，本目录的渲染器负责整条消息的呈现。
///
/// ## 共享约定
///
/// - **右键菜单统一挂在注册层**：所有核心渲染器的产出都经
///   `MessageContextMenu.attach` 包一层，保证 V1–V5（含不使用
///   `MessageViewChrome` 的 ZCode / ChatGPT 气泡与正文）行为一致。
///   挂在各视图内部会漏掉绕过 chrome 的那一批。
/// - **verbosity 分派**：每个渲染器按 `ResponseVerbosity` 选择具体视图，
///   V4（ZCode）/ V5（ChatGPT）有各自的呈现。
/// - **兜底优先级**：`core-default-markdown` 的 order 最低，只要没有更高
///   优先级的渲染器能处理，就由它接管。
enum CoreMessageRenderer {
    /// 渲染优先级基数（与旧版内核一致）。
    static let baseOrder: Int = 10

    /// 全部核心渲染器的 ID。插件入口按此列表注销。
    static let rendererIDs: [String] = [
        "core-turn-completed",
        "core-context-compaction",
        "core-agent-loop-retry",
        "core-goal-task-continuation",
        "core-model-switched",
        "core-status-message",
        "core-error-message",
        "core-tool-message",
        "core-user-message",
        "core-tool-step-group",
        "core-assistant-message",
        "core-system-message",
        "core-default-markdown",
    ]

    /// 给一条消息的渲染结果挂上统一右键菜单。
    ///
    /// - Important: 菜单挂在**注册层**而不是各个具体视图里，是为了 V1–V5
    ///   行为完全一致：V4/V5（ZCode / ChatGPT）用的是独立渲染器，
    ///   **不走** `MessageViewChrome`，挂视图内部会漏掉这批行。
    @MainActor
    static func attachMenu(
        to view: AnyView,
        capability: (any MessageRendererCapability)?,
        message: Message
    ) -> AnyView {
        MessageContextMenu.attach(
            to: view,
            capability: capability,
            message: message
        )
    }
}
