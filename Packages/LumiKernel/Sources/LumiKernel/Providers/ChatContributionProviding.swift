import Foundation
import LumiCoreMessage
import LumiCoreLLMProvider

/// Chat 贡献聚合服务
///
/// 把"插件 → ChatService 贡献物"的收集能力抽象出来,让 ChatService 能直接消费
/// `PluginService` 提供的 LLM Provider / 发送中间件 / 消息渲染器 / turn 结束钩子。
@MainActor
public protocol ChatContributionProviding: AnyObject {
    /// 收集所有启用插件的 LLM Provider
    func allLLMProviders() -> [any LumiLLMProvider]

    /// 收集所有启用插件的发送中间件
    func allSendMiddlewares() -> [any LumiSendMiddleware]

    /// 收集所有启用插件的消息渲染器
    func allMessageRenderers() -> [LumiMessageRendererItem]

    /// Agent turn 结束后通知所有启用插件
    func dispatchTurnFinished(conversationID: UUID, reason: LumiTurnEndReason) async
}
