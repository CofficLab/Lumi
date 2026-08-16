import Combine
import Foundation
import ProviderAgentLoop
import ProviderConversation
import ProviderMessage
import ProviderMessageRendering
import ProviderMessageSender
import ProviderMessageStreaming
import ProviderToolManager

/// 新版 PluginMessageList 的服务容器。
///
/// 旧版 ViewModel 直接持有 `KernelLumi` 并访问 `kernel.messageManager` 等；
/// 新版改为在插件 `onBoot` 时解析全部 Provider，集中在这里传给各视图模型。
/// 全部为可选，允许部分 Provider 尚未注入时优雅降级（与旧版一致）。
@MainActor
struct MessageListServices {
    let conversations: (any ConversationManaging)?
    let messages: (any MessageManaging)?
    let rendering: (any MessageRenderingProviding)?
    let sender: (any MessageSendingProviding)?
    let streaming: (any MessageStreamingProviding)?
    let toolManager: (any ToolManagerProviding)?
    let agentTurn: (any AgentLoopProviding)?

    var selectedConversationID: UUID? {
        conversations?.selectedConversationID
    }

    func verbosity(for conversationID: UUID?) -> LumiResponseVerbosity {
        conversations?.verbosity(for: conversationID) ?? .defaultVerbosity
    }

    /// 注册选中对话变化观察者（替代旧版 `.lumiSelectedConversationDidChange` 通知）。
    ///
    /// 由 `ConversationManaging` 的新 callback 机制驱动，仅在选中值实际变化时回调。
    /// 无会话 Provider 时返回 no-op 令牌（不接收任何通知），与旧版降级行为一致。
    @discardableResult
    func addSelectedConversationObserver(
        _ callback: @escaping (UUID?) -> Void
    ) -> (any SelectedConversationObserverHandle)? {
        conversations?.addSelectedConversationObserver(callback)
    }

    /// 会话状态变化（列表/设置项变化）的窄播，替代旧版 `.lumiConversationsDidChange` 通知。
    ///
    /// 订阅 `ConversationManaging.objectWillChange`：任何会话级 @Published 变化都会触发，
    /// 包括列表刷新、verbosity 等设置更新。`receive(on:)` 让回调在属性写入完成后执行。
    var conversationsChangesPublisher: AnyPublisher<Void, Never> {
        guard let conversations else { return Empty().eraseToAnyPublisher() }
        return conversations.objectWillChange
            .map { _ in () }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}
