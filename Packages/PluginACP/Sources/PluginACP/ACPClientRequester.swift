import Foundation
import ProviderACP

/// Agent → Client 出站请求的收发器。
///
/// ACP 中 Agent 会主动向 Client 发起若干请求（`session/request_permission`、
/// `fs/read_text_file`、`fs/write_text_file`），这些请求的响应是**异步**回来的：
/// `ACPProtocolHandler` 只负责把响应转交本类型，由本类型按 `id` 唤醒发起方。
///
/// 设计要点：
/// - 每个出站请求分配唯一自增 `id`，并以 continuation 挂起等待响应；
/// - 响应 / 错误 / 超时 / 会话取消四条路径都保证恰好 resume 一次；
/// - 超时兜底：ACP v1 未约定 Client 响应超时，但挂起请求会让回合永久悬挂，
///   因此约定超时上限（`LUMI_ACP_REQUEST_TIMEOUT` 可调）。
@MainActor
public final class ACPClientRequester {
    /// 单个挂起请求的等待者。
    private struct Waiter {
        let continuation: CheckedContinuation<JSONValue?, Error>
        let timeoutTask: Task<Void, Never>
        /// 会话边界：会话取消时只作废该会话的请求。
        let sessionID: ACPSessionId?
    }

    /// 出站请求失败原因。
    public enum RequestError: Error, LocalizedError {
        /// 等待 Client 响应超时。
        case timeout(method: String)
        /// 请求被取消（回合结束 / `session/cancel` / 连接关闭）。
        case cancelled(method: String)
        /// Client 返回了 JSON-RPC 错误。
        case remote(ACPError)

        public var errorDescription: String? {
            switch self {
            case .timeout(let method):
                return "ACP request timed out: \(method)"
            case .cancelled(let method):
                return "ACP request cancelled: \(method)"
            case .remote(let error):
                return "ACP request failed (\(error.code)): \(error.message)"
            }
        }
    }

    private let onSend: @MainActor (ACPMessage) -> Void
    /// 默认请求超时（秒）。
    private let defaultTimeout: TimeInterval
    /// 权限请求超时（秒）。权限需要用户在场决策，默认显著放宽。
    private let permissionTimeout: TimeInterval

    /// Agent 自发出站请求的起始 ID。
    ///
    /// Client 的请求 ID 通常从 1 递增；Agent 侧从 1000 起分配，使同一连接上
    /// 两个方向的 ID 不会在日志与排查中混淆（JSON-RPC 本身按方向隔离 ID）。
    private static let firstRequestID = 1000

    private var nextID = ACPClientRequester.firstRequestID
    private var waiters: [JSONValue: Waiter] = [:]

    public init(
        onSend: @escaping @MainActor (ACPMessage) -> Void,
        timeout: TimeInterval? = nil,
        permissionTimeout: TimeInterval? = nil
    ) {
        self.onSend = onSend
        let resolved = timeout
            ?? ProcessInfo.processInfo.environment["LUMI_ACP_REQUEST_TIMEOUT"]
                .flatMap(TimeInterval.init)
            ?? 60
        self.defaultTimeout = resolved
        self.permissionTimeout = permissionTimeout ?? max(resolved, 300)
    }

    /// 挂起中的请求数量（测试与诊断用）。
    public var pendingCount: Int { waiters.count }

    // MARK: - 发起请求

    /// 发起一次出站请求并等待 Client 响应。
    ///
    /// - Parameters:
    ///   - method: ACP 方法名（`ACPMethod.*`）。
    ///   - params: 已编码的参数载荷。
    ///   - sessionID: 归属会话；会话取消时该请求被作废。
    ///   - timeout: 覆盖默认超时。
    /// - Returns: 响应 `result`（`null` 语义由调用方按方法解释）。
    public func request(
        method: String,
        params: JSONValue,
        sessionID: ACPSessionId?,
        timeout: TimeInterval? = nil
    ) async throws -> JSONValue? {
        let id = JSONValue.number(Double(nextID))
        nextID += 1
        let effectiveTimeout = timeout ?? defaultTimeout

        let message = ACPMessage.request(id: id, method: method, params: params)

        return try await withCheckedThrowingContinuation { continuation in
            let timeoutTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(effectiveTimeout))
                guard let self, self.waiters[id] != nil else { return }
                self.finish(id: id, with: .failure(RequestError.timeout(method: method)))
            }
            waiters[id] = Waiter(
                continuation: continuation,
                timeoutTask: timeoutTask,
                sessionID: sessionID
            )
            onSend(message)
        }
    }

    /// 发起 `session/request_permission` 并等待用户决定。
    public func requestPermission(
        _ params: ACPRequestPermissionParams
    ) async throws -> ACPRequestPermissionResult {
        let result = try await request(
            method: ACPMethod.sessionRequestPermission,
            params: try JSONValue.stringify(params),
            sessionID: params.sessionId,
            timeout: permissionTimeout
        )
        guard let result else {
            throw RequestError.remote(.invalidParams)
        }
        return try result.decoded(as: ACPRequestPermissionResult.self)
    }

    // MARK: - 响应处理

    /// 收到 Client 的成功响应。
    public func handleResponse(id: JSONValue, result: JSONValue?) {
        finish(id: id, with: .success(result))
    }

    /// 收到 Client 的错误响应（如 `-32800` 取消）。
    public func handleError(id: JSONValue, error: ACPError) {
        finish(id: id, with: .failure(RequestError.remote(error)))
    }

    /// 作废指定会话的全部挂起请求（`session/cancel` 或回合收尾）。
    public func cancelRequests(for sessionID: ACPSessionId) {
        let ids = waiters.filter { $0.value.sessionID == sessionID }.map(\.key)
        for id in ids {
            finish(id: id, with: .failure(RequestError.cancelled(method: "session/\(sessionID.rawValue)")))
        }
    }

    /// 作废全部挂起请求（连接关闭）。
    public func cancelAll() {
        for id in Array(waiters.keys) {
            finish(id: id, with: .failure(RequestError.cancelled(method: "connection closing")))
        }
    }

    // MARK: - 内部

    /// 结束一个挂起请求。重复调用无副作用（waiter 已移除时直接返回）。
    private func finish(id: JSONValue, with result: Result<JSONValue?, Error>) {
        guard let waiter = waiters.removeValue(forKey: id) else { return }
        waiter.timeoutTask.cancel()
        waiter.continuation.resume(with: result)
    }
}
