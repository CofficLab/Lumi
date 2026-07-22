import Foundation



/// Chat 贡献协议 (LumiCoreChat 消费版本)
///
/// 把"插件 → ChatService 贡献物"的收集能力抽象出来，让 `ChatService` 能直接消费
/// `PluginService` 提供的 LLM Provider / 发送中间件 / 消息渲染器 / turn 结束钩子，
/// 而不需要 App 层在 `RootContainer` 里手工拼装这些注册调用。
///
/// 与 `LumiPluginToolManaging`（工具/子 Agent 贡献）是并列关系：
/// - 本协议负责 ChatService 维度的贡献（providers/middlewares/renderers/turn hook）；
/// - `LumiPluginToolManaging` 负责工具维度，由 `AgentToolComponent.buildToolSet` 消费。
///
/// 实现者通常是 App 层的 `PluginService`。`ChatService.applyPluginContributions`
/// 会调用这些方法完成贡献物的注册。
@MainActor
public protocol LumiChatContributionProviding: AnyObject {
    /// 收集所有启用插件的 LLM Provider
    func llmProviders(lumiCore: any LumiCoreProviding) -> [any LumiLLMProvider]

    /// 收集所有启用插件的发送中间件
    func sendMiddlewares(lumiCore: any LumiCoreProviding) -> [any LumiSendMiddleware]

    /// 收集所有启用插件的消息渲染器
    func messageRenderers(lumiCore: any LumiCoreProviding) -> [LumiMessageRendererItem]

    /// Agent turn 结束后通知所有启用插件
    func onTurnFinished(lumiCore: any LumiCoreProviding, conversationID: UUID, reason: LumiTurnEndReason) async
}
