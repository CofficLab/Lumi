import Foundation
import KernelCore
import ProviderConversation
import ProviderToolManager

/// AskUser 插件：注册 `ask_user` 工具，让 LLM 可向用户提问并等待回答。
///
/// 复刻自旧版 `Plugins/AskUserPlugin`：
/// - 注册 `AskUserTool` 到 `ToolManagerProviding`；
/// - 工具 `executeResult` 返回 `awaitingUserResponse: true`，AgentLoop 检测后
///   创建 suspension（kind = "userInput"）并暂停回合；
/// - 用户回答后经 `AgentLoopProviding.resumeTurn(in:request:)` 恢复。
///
/// UI 渲染由消息列表层读取 suspension + tool payload 展示（与旧版
/// AskUserBridge / RowRenderer 对应，可在消息渲染插件中消费 `AgentLoopEvent`）。
@MainActor
public final class AskUserPlugin: SuperPlugin {
    /// 保持旧版插件 ID。
    public let id = "com.coffic.lumi.plugin.ask-user"
    public let order = 88

    public init() {}

    public var metadata: PluginMetadata {
        PluginMetadata(
            id: id,
            name: "Ask User",
            description: "Ask the user a question and wait for their response",
            category: .chat,
            stage: .preview,
            policy: .alwaysOn
        )
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let conversations = kernel.resolveProvider((any ConversationManaging).self),
              let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) else {
            return
        }
        toolManager.add(AskUserTool(conversations: conversations), pluginID: id)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ToolManagerProviding).self)?
            .remove(id: AskUserTool.toolName)
    }
}
