import Foundation
import ProviderConversation
import ProviderMessage

/// 新版 PluginMessageList 的服务容器。
///
/// 旧版 VM 直接持有 `KernelLumi` 并访问 `kernel.messageManager` 等；
/// 新版改为在插件 `onBoot` 时解析全部 Provider，经 `Capabilities/` 收窄为
/// 最小能力协议后集中在这里传给各视图模型。
/// 全部为可选，允许部分 Provider 尚未注入时优雅降级（与旧版一致）。
@MainActor
struct MessageListServices {
    let conversations: (any MessageListConversationCapability)?
    let developerMode: (any MessageListDeveloperModeCapability)?
    let messages: (any MessageListMessageCapability)?
    let rendering: (any MessageListRenderingCapability)?
    let toolManager: (any MessageListToolManagerCapability)?
    let agentTurn: (any MessageListAgentLoopCapability)?
    var selectedConversationID: UUID? {
        conversations?.selectedConversationID
    }

    func verbosity(for conversationID: UUID?) -> ResponseVerbosity {
        conversations?.verbosity(for: conversationID) ?? .defaultVerbosity
    }
}
