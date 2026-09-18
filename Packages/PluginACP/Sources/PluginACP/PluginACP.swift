import Foundation
import KernelCore
import ProviderACP
import ProviderAgentLoop
import ProviderConversation
import ProviderMessage

/// ACP 插件：把 Lumi 内核暴露为 ACP Agent。
///
/// 生命周期：作为 SuperPlugin 注册进内核（复用内核的 Provider 装配与
/// 生命周期管理）；`startACPServer(transport:)` 仅在 headless 入口
/// （lumi-acp 可执行文件）调用，GUI 下不自动启动 stdio 服务。
@MainActor
public final class PluginACP: SuperPlugin {
    public let id = "acp"
    /// 需晚于 ConversationManager(order=7)、AgentLoop(order=8)、ToolManager(默认 200 之后)。
    public var order: Int = 250

    public let metadata: PluginMetadata

    private let config: ACPConfig
    private weak var kernel: KernelCoreContainer?
    private var server: ACPStdioServer?
    private var coordinator: ACPTurnCoordinator?

    /// 输入 EOF 回调（透传自 stdio 服务器），宿主可据此退出进程。
    public var onEOF: (() -> Void)?

    public init(config: ACPConfig = .default) {
        self.config = config
        self.metadata = PluginMetadata(
            id: "acp",
            name: "ACP",
            description: "Agent Client Protocol: expose the Lumi agent to external editors over stdio",
            version: "0.1.0"
        )
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        self.kernel = kernel
    }

    /// 启动 ACP stdio 服务器。
    ///
    /// 由 headless 入口在 `makeKernel(additionalPlugins: [plugin])` 之后调用；
    /// 此时内核已完成 Boot，ConversationManaging / AgentLoopProviding /
    /// MessageManaging 均为最终实例。
    public func startACPServer(transport: any ACPTransport) throws {
        guard let kernel else {
            throw ACPPluginError.kernelNotBooted
        }
        guard let conversations = kernel.resolveProvider((any ConversationManaging).self) else {
            throw ACPPluginError.missingProvider("ConversationManaging")
        }
        guard let agentLoop = kernel.resolveProvider((any AgentLoopProviding).self) else {
            throw ACPPluginError.missingProvider("AgentLoopProviding")
        }
        guard let messages = kernel.resolveProvider((any MessageManaging).self) else {
            throw ACPPluginError.missingProvider("MessageManaging")
        }

        let sessions = ACPSessionManager(
            conversationFactory: ConversationCreatingAdapter(conversations)
        )
        let handler = ACPProtocolHandler(config: config, sessions: sessions)
        let server = ACPStdioServer(transport: transport, handler: handler)
        server.onEOF = { [weak self] in
            self?.onEOF?()
        }

        // 回合协调器：事件流 / 异步响应经服务器发回 Client。
        let coordinator = ACPTurnCoordinator(
            agentLoop: AgentLoopAdapter(agentLoop),
            messages: MessageManagerAdapter(messages),
            sessions: sessions,
            onSend: { [weak server] message in
                server?.sendToClient(message)
            }
        )
        handler.coordinator = coordinator
        self.coordinator = coordinator

        try server.start()
        self.server = server
    }

    /// 停止 ACP 服务器（退出前调用）。
    public func stopACPServer() {
        server?.stop()
        server = nil
        coordinator = nil
    }

    public enum ACPPluginError: Error, LocalizedError {
        case kernelNotBooted
        case missingProvider(String)

        public var errorDescription: String? {
            switch self {
            case .kernelNotBooted:
                return "ACP plugin not booted: call startACPServer after the kernel has booted"
            case .missingProvider(let name):
                return "ACP plugin requires provider: \(name)"
            }
        }
    }
}

/// 把 `any ConversationManaging` 桥接为 `ACPSessionCreating`。
@MainActor
private final class ConversationCreatingAdapter: ACPSessionCreating {
    private let conversations: any ConversationManaging

    init(_ conversations: any ConversationManaging) {
        self.conversations = conversations
    }

    func createConversation(
        title: String?,
        projectPath: String?,
        providerID: String?,
        modelName: String?
    ) throws -> UUID {
        try conversations.createConversation(
            title: title,
            projectPath: projectPath,
            providerID: providerID,
            modelName: modelName
        )
    }
}

/// 把 `any AgentLoopProviding` 桥接为 `ACPTurnRunning`。
@MainActor
private final class AgentLoopAdapter: ACPTurnRunning {
    private let agentLoop: any AgentLoopProviding

    init(_ agentLoop: any AgentLoopProviding) {
        self.agentLoop = agentLoop
    }

    func addAgentLoopObserver(
        _ callback: @escaping (AgentLoopEvent) -> Void
    ) -> any AgentLoopObserverHandle {
        agentLoop.addAgentLoopObserver(callback)
    }

    func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome {
        try await agentLoop.runTurn(in: conversationID)
    }

    func resumeTurn(
        in conversationID: UUID,
        request: AgentTurnResumeRequest
    ) async throws -> AgentLoopOutcome {
        try await agentLoop.resumeTurn(in: conversationID, request: request)
    }

    func cancelTurn(in conversationID: UUID) {
        agentLoop.cancelTurn(in: conversationID)
    }

    func setAutoReplySuppressed(_ suppressed: Bool, for conversationID: UUID) {
        agentLoop.setAutoReplySuppressed(suppressed, for: conversationID)
    }
}

/// 把 `any MessageManaging` 桥接为 `ACPMessageReading`。
@MainActor
private final class MessageManagerAdapter: ACPMessageReading {
    private let messages: any MessageManaging

    init(_ messages: any MessageManaging) {
        self.messages = messages
    }

    func insertMessage(_ message: Message, to conversationID: UUID) {
        messages.insertMessage(message, to: conversationID)
    }

    func messagesSnapshot(in conversationID: UUID) -> [Message] {
        messages.messages(for: conversationID)
    }
}
