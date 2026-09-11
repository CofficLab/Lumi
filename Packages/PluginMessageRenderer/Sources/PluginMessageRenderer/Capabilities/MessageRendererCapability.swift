import Foundation
import KernelCore
import KitAgentTool
import ProviderConversation
import ProviderDeveloperMode
import ProviderMessageRendering
import ProviderMessageSender
import ProviderToolManager

/// 消息渲染器需要的外部操作集合。
///
/// 收敛 ToolManager / MessageSending / ToolCallRendering / DeveloperMode 的调用面，
/// 渲染 View 只通过本能力发起外部操作，不再直接解析 Kernel。
@MainActor
protocol MessageRendererCapability: AnyObject {
    // MARK: 工具调用结果

    /// 按会话/回合查询一次工具调用的持久化结果。
    func toolCallResult(
        for toolCallID: String,
        conversationID: UUID,
        turnID: UUID?
    ) async -> ToolCallResult?

    // MARK: 重发消息

    /// 以相同内容重发消息（等价于内核发送）。
    func resendMessage(content: String, conversationID: UUID) async

    // MARK: 自定义工具行渲染器

    /// 命中自定义工具调用行渲染器时返回，否则 `nil`。
    func toolCallRenderer(for toolCall: ToolCall) -> (any ToolCallRowRenderer)?

    // MARK: 工具执行进度

    /// 构造单个工具 job 的活动观察模型（供行内状态视图使用）。
    func makeToolJobActivityModel(
        toolCallID: String,
        conversationID: UUID,
        turnID: UUID?
    ) -> ToolJobActivityModel

    // MARK: 开发者模式

    var isDeveloperModeEnabled: Bool { get }
    func addDeveloperModeObserver(
        _ callback: @escaping (DeveloperModeProvidingEvent) -> Void
    ) -> any DeveloperModeProvidingObserverHandle
}

/// 将内核 Provider 收窄为消息渲染器能力（组装层创建，View 不接触）。
@MainActor
final class MessageRendererCapabilityAdapter: MessageRendererCapability {
    private weak var toolManager: (any ToolManagerProviding)?
    private weak var messageSending: (any MessageSendingProviding)?
    private weak var toolCallRendering: (any ToolCallRenderingProviding)?
    private weak var developerMode: (any DeveloperModeProviding)?

    init(kernel: KernelCoreContainer) {
        toolManager = kernel.resolveProvider((any ToolManagerProviding).self)
        messageSending = kernel.resolveProvider((any MessageSendingProviding).self)
        toolCallRendering = kernel.resolveProvider((any ToolCallRenderingProviding).self)
        developerMode = kernel.resolveProvider((any DeveloperModeProviding).self)
    }

    func toolCallResult(
        for toolCallID: String,
        conversationID: UUID,
        turnID: UUID?
    ) async -> ToolCallResult? {
        await toolManager?.toolCallResult(
            for: toolCallID,
            conversationID: conversationID,
            turnID: turnID
        )
    }

    func resendMessage(content: String, conversationID: UUID) async {
        try? await messageSending?.sendMessage(content, conversationID: conversationID)
    }

    func toolCallRenderer(for toolCall: ToolCall) -> (any ToolCallRowRenderer)? {
        toolCallRendering?.renderer(for: toolCall)
    }

    func makeToolJobActivityModel(
        toolCallID: String,
        conversationID: UUID,
        turnID: UUID?
    ) -> ToolJobActivityModel {
        ToolJobActivityModel(
            manager: toolManager,
            toolCallID: toolCallID,
            conversationID: conversationID,
            turnID: turnID
        )
    }

    var isDeveloperModeEnabled: Bool {
        developerMode?.isEnabled ?? false
    }

    func addDeveloperModeObserver(
        _ callback: @escaping (DeveloperModeProvidingEvent) -> Void
    ) -> any DeveloperModeProvidingObserverHandle {
        developerMode?.addObserver(callback) ?? NoopDeveloperModeProvidingObserverHandle()
    }
}
