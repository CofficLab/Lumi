import Foundation
import KernelCore
import ProviderACP

/// ACP 方法分发器：把 Client 发来的 JSON-RPC 请求/通知
/// 映射为 Lumi 内核调用，并构造协议响应。
///
/// M2 范围：`initialize` 握手、`session/new`。
/// M3+ 扩展点：`session/prompt`、`session/cancel`、`session/update` 事件桥。
@MainActor
public final class ACPProtocolHandler {
    /// 未识别的请求方法 → JSON-RPC `methodNotFound`。
    static let methodNotFoundError = ACPError.methodNotFound

    public let config: ACPConfig
    public let sessions: ACPSessionManager
    /// 内核引用，M3 的 prompt 回合需要解析 AgentLoop / ToolManager。
    public let kernel: KernelCoreContainer?

    public init(
        config: ACPConfig,
        sessions: ACPSessionManager,
        kernel: KernelCoreContainer? = nil
    ) {
        self.config = config
        self.sessions = sessions
        self.kernel = kernel
    }

    /// 处理一条入站消息，返回需要发回给 Client 的消息（响应或通知）。
    ///
    /// - 请求 → 响应（成功或错误）。
    /// - 通知 → 无响应（返回 nil）。
    /// - 响应/错误（来自 Client）→ 忽略（返回 nil）。
    public func handle(_ message: ACPMessage) -> ACPMessage? {
        switch message {
        case .request(let id, let method, let params):
            return handleRequest(id: id, method: method, params: params)
        case .notification:
            return nil
        case .response, .error:
            return nil
        }
    }

    // MARK: - Request 分发

    private func handleRequest(id: JSONValue, method: String, params: JSONValue?) -> ACPMessage {
        switch method {
        case ACPMethod.initialize:
            return respondInitialize(id: id, params: params)
        case ACPMethod.sessionNew:
            return respondSessionNew(id: id, params: params)
        default:
            return .error(id: id, error: Self.methodNotFoundError)
        }
    }

    // MARK: - initialize

    private func respondInitialize(id: JSONValue, params: JSONValue?) -> ACPMessage {
        guard let params,
              let decoded = try? params.decoded(as: ACPInitializeParams.self) else {
            return .error(id: id, error: .invalidParams)
        }

        // 版本协商：Agent 只支持协议版本 1。
        // 若 Client 声明的主版本与 Agent 不同，Agent 仍应答自身版本，
        // 由 Client 决定是否继续（ACP 规范）。
        let result = ACPInitializeResult(
            protocolVersion: ACPVersion.current,
            agentCapabilities: ACPAgentCapabilities(
                loadSession: false,
                promptCapabilities: ACPPromptCapabilities(
                    image: false,
                    audio: false,
                    embeddedContext: false
                ),
                mcpCapabilities: nil,
                auth: nil,
                sessionCapabilities: nil
            ),
            agentInfo: ACPImplementationInfo(
                name: config.agentName,
                title: config.agentTitle,
                version: config.agentVersion
            ),
            authMethods: []
        )

        do {
            return try ACPMessage.makeResponse(id: id, result: result)
        } catch {
            return .error(id: id, error: .internalError)
        }
    }

    // MARK: - session/new

    private func respondSessionNew(id: JSONValue, params: JSONValue?) -> ACPMessage {
        guard let params,
              let decoded = try? params.decoded(as: ACPSessionNewParams.self) else {
            return .error(id: id, error: .invalidParams)
        }
        guard !decoded.cwd.isEmpty else {
            return .error(id: id, error: .invalidParams)
        }

        do {
            let sessionID = try sessions.createSession(cwd: decoded.cwd)
            let result = ACPSessionNewResult(sessionId: sessionID)
            return try ACPMessage.makeResponse(id: id, result: result)
        } catch {
            return .error(
                id: id,
                error: ACPError(
                    code: ACPErrorCode.internalError,
                    message: "Failed to create session: \(error.localizedDescription)"
                )
            )
        }
    }
}
