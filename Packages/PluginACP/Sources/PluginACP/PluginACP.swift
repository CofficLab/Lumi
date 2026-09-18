import Foundation
import KitAgentTool
import KernelCore
import ProviderACP
import ProviderAgentLoop
import ProviderConversation
import ProviderMessage
import ProviderMessageStreaming
import ProviderToolManager

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
    /// 已注册的 fs 桥接工具（停止时撤回）。
    private var registeredFileTools: [any SuperAgentTool] = []

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

        // 出站请求收发器：请求经服务器发回 Client，响应按 id 唤醒等待者。
        let requester = ACPClientRequester { [weak server] message in
            server?.sendToClient(message)
        }
        handler.requester = requester

        // 回合协调器：事件流 / 异步响应经服务器发回 Client。
        // 若内核提供流式 store，则接上增量桥，让编辑器实时看到 token。
        let streamingBridge = kernel.resolveProvider((any MessageStreamingProviding).self)
            .map { ACPStreamingBridge(stream: MessageStreamingAdapter($0)) }
        let coordinator = ACPTurnCoordinator(
            agentLoop: AgentLoopAdapter(agentLoop),
            messages: MessageManagerAdapter(messages),
            sessions: sessions,
            requester: requester,
            streaming: streamingBridge,
            onSend: { [weak server] message in
                server?.sendToClient(message)
            }
        )
        handler.coordinator = coordinator
        self.coordinator = coordinator

        try server.start()
        self.server = server

        // Client 能力只在 `initialize` 中声明，此刻还无从判断；挂在回调上，
        // 待能力确定后按需启用 fs 桥（幂等，重复 initialize 只装一次）。
        handler.onClientCapabilitiesUpdated = { [weak self] in
            self?.installFileSystemBridgeIfNeeded(
                handler: handler,
                requester: requester,
                sessions: sessions,
                kernel: kernel
            )
        }
    }

    /// Client 声明 fs 能力后，注册经编辑器的文件工具覆盖内置实现。
    ///
    /// 之所以覆盖而非新增：模型仍调用 `read_file` / `write_file`，但读写改走
    /// 编辑器环境，未保存缓冲区与编辑器 diff 视图天然正确。
    private func installFileSystemBridgeIfNeeded(
        handler: ACPProtocolHandler,
        requester: ACPClientRequester,
        sessions: ACPSessionManager,
        kernel: KernelCoreContainer
    ) {
        guard handler.clientCapabilities.hasFileSystemBridge,
              registeredFileTools.isEmpty,
              let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) else {
            return
        }
        let fileClient = ACPFileClient(
            requester: requester,
            capabilities: handler.clientCapabilities,
            sessions: sessions
        )
        let bridge = ACPFileBridge(
            client: fileClient,
            sessions: sessions,
            capabilities: handler.clientCapabilities
        )
        let tools: [any SuperAgentTool] = [
            ACPReadFileTool(bridge: bridge),
            ACPWriteFileTool(bridge: bridge),
        ]
        for tool in tools {
            toolManager.add(tool, pluginID: id)
        }
        registeredFileTools = tools
    }

    /// 停止 ACP 服务器（退出前调用）。
    public func stopACPServer() {
        server?.stop()
        server = nil
        coordinator = nil
        // 撤回 fs 桥工具，恢复内核自带文件工具。
        if let kernel,
           let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) {
            for tool in registeredFileTools {
                toolManager.remove(id: tool.name)
            }
        }
        registeredFileTools = []
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

/// 把 `any MessageStreamingProviding` 桥接为 `ACPStreamObserving`。
@MainActor
private final class MessageStreamingAdapter: ACPStreamObserving {
    private let stream: any MessageStreamingProviding

    init(_ stream: any MessageStreamingProviding) {
        self.stream = stream
    }

    func addACPStreamObserver(
        _ callback: @escaping (UUID) -> Void
    ) -> any ACPStreamObserverHandle {
        let handle = stream.addMessageStreamingObserver { change in
            // `updated` 携带会话 ID；流式追加即触发。
            if case .updated(let conversationID) = change {
                callback(conversationID)
            }
        }
        return MessageStreamObserverHandle(handle)
    }

    func acpStreamingContent(for conversationID: UUID) -> String? {
        guard let message = stream.streamingMessage(for: conversationID) else { return nil }
        return message.content
    }
}

/// 令牌适配：把 MessageStreaming 的注销令牌转成 ACP 侧协议。
@MainActor
private final class MessageStreamObserverHandle: ACPStreamObserverHandle {
    private let handle: any MessageStreamingObserverHandle

    init(_ handle: any MessageStreamingObserverHandle) {
        self.handle = handle
    }

    func cancel() {
        handle.cancel()
    }
}
