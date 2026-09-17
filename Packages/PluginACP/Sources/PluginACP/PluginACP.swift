import Foundation
import KernelCore
import ProviderACP
import ProviderConversation

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
    /// 此时内核已完成 Boot，ConversationManaging 为最终实例。
    public func startACPServer(transport: any ACPTransport) throws {
        guard let kernel else {
            throw ACPPluginError.kernelNotBooted
        }
        guard let conversations = kernel.resolveProvider((any ConversationManaging).self) else {
            throw ACPPluginError.missingProvider("ConversationManaging")
        }

        let sessions = ACPSessionManager(
            conversationFactory: ConversationCreatingAdapter(conversations)
        )
        let handler = ACPProtocolHandler(
            config: config,
            sessions: sessions,
            kernel: kernel
        )
        let server = ACPStdioServer(transport: transport, handler: handler)
        server.onEOF = { [weak self] in
            self?.onEOF?()
        }
        try server.start()
        self.server = server
    }

    /// 停止 ACP 服务器（退出前调用）。
    public func stopACPServer() {
        server?.stop()
        server = nil
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
///
/// Swift 的 existential 转换不推断结构性 conformance：
/// `any ConversationManaging` 不能直接传给需要 `any ACPSessionCreating`
/// 的参数，需显式适配。
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
