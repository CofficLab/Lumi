import Foundation
import KernelCore
import ProviderACP

/// ACP 方法分发器：把 Client 发来的 JSON-RPC 请求/通知
/// 映射为 Lumi 内核调用，并构造协议响应。
///
/// - 同步方法（`initialize` / `session/new`）：直接返回响应。
/// - 异步方法（`session/prompt`）：交给 `ACPTurnCoordinator` 启动回合，
///   最终响应与 `session/update` 通知通过 `onSend` 异步发出。
/// - 通知（`session/cancel`）：转发给 coordinator。
/// - 响应（permission 回执）：转交 coordinator 恢复挂起回合。
@MainActor
public final class ACPProtocolHandler {
    public let config: ACPConfig
    public let sessions: ACPSessionManager
    /// Client 能力登记簿（`initialize` 时写入）。
    public let clientCapabilities: ACPClientCapabilitiesStore
    /// 回合协调器（装配阶段注入；session/prompt 依赖）。
    public var coordinator: ACPTurnCoordinator?

    /// 出站请求收发器（由服务器注入；`session/request_permission` / `fs/*` 依赖）。
    public var requester: ACPClientRequester?

    /// 异步消息发送通道（由服务器注入，转发到传输层）。
    public var onSend: ((ACPMessage) -> Void)?

    public init(
        config: ACPConfig,
        sessions: ACPSessionManager,
        coordinator: ACPTurnCoordinator? = nil,
        clientCapabilities: ACPClientCapabilitiesStore = ACPClientCapabilitiesStore()
    ) {
        self.config = config
        self.sessions = sessions
        self.coordinator = coordinator
        self.clientCapabilities = clientCapabilities
    }

    /// 处理一条入站消息。
    ///
    /// - 同步请求 → 返回响应。
    /// - 异步请求 → 返回 nil（响应稍后经 `onSend` 发送）。
    /// - 通知 → 返回 nil。
    /// - 响应 → 返回 nil。
    public func handle(_ message: ACPMessage) -> ACPMessage? {
        switch message {
        case .request(let id, let method, let params):
            return handleRequest(id: id, method: method, params: params)
        case .notification(let method, let params):
            handleNotification(method: method, params: params)
            return nil
        case .response(let id, let result):
            handleResponse(id: id, result: result)
            return nil
        case .error(let id, let error):
            // Agent 主动发起的请求（权限 / fs）失败：唤醒对应等待者。
            requester?.handleError(id: id, error: error)
            return nil
        }
    }

    // MARK: - Request 分发

    private func handleRequest(id: JSONValue, method: String, params: JSONValue?) -> ACPMessage? {
        switch method {
        case ACPMethod.initialize:
            return respondInitialize(id: id, params: params)
        case ACPMethod.sessionNew:
            return respondSessionNew(id: id, params: params)
        case ACPMethod.sessionPrompt:
            return respondSessionPrompt(id: id, params: params)
        default:
            return .error(id: id, error: .methodNotFound)
        }
    }

    // MARK: - Notification 分发

    private func handleNotification(method: String, params: JSONValue?) {
        switch method {
        case ACPMethod.sessionCancel:
            if let decoded = try? params?.decoded(as: ACPCancelParams.self) {
                coordinator?.cancel(sessionID: decoded.sessionId)
            }
        default:
            break
        }
    }

    // MARK: - Response 分发

    private func handleResponse(id: JSONValue, result: JSONValue?) {
        // Agent 主动发起的请求（权限 / fs）的响应由 requester 按 id 认领。
        requester?.handleResponse(id: id, result: result)
    }

    // MARK: - initialize

    private func respondInitialize(id: JSONValue, params: JSONValue?) -> ACPMessage {
        guard let params,
              let decoded = try? params.decoded(as: ACPInitializeParams.self) else {
            return .error(id: id, error: .invalidParams)
        }

        // 能力是连接级的：记录 Client 声明，供 fs 桥与权限桥判断。
        clientCapabilities.update(from: decoded.clientCapabilities)

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

    // MARK: - session/prompt（异步）

    private func respondSessionPrompt(id: JSONValue, params: JSONValue?) -> ACPMessage? {
        guard let coordinator else {
            return .error(id: id, error: .internalError)
        }
        guard let params,
              let decoded = try? params.decoded(as: ACPPromptParams.self) else {
            return .error(id: id, error: .invalidParams)
        }

        if let error = coordinator.startTurn(
            sessionID: decoded.sessionId,
            requestID: id,
            prompt: decoded.prompt
        ) {
            return .error(
                id: id,
                error: ACPError(code: ACPErrorCode.invalidParams, message: error)
            )
        }

        // 回合已启动：最终响应随事件流异步返回。
        return nil
    }
}
