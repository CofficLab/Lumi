import Foundation
import KitAgentTool
import LumiLoggingKit
import os

/// Computer Use 授权协调器。
///
/// 负责聊天内授权卡片的两个方向：
/// 1. **请求方向**：工具在命中未授权应用时构造请求载荷，交由宿主挂起回合；
/// 2. **决策方向**：用户在卡片上做出决定后，把决定落到授权存储。
///
/// 决策落地后，工具会被重新执行一次；这一次授权已经生效，工具直接放行。
/// 「允许一次」的授权在这次检查时被消费，因此它**只对紧接着的这一���操作有效**。
/// - Note: 不做 actor 隔离。渲染器的 `canRender` 是非隔离调用点，
///   而它需要读取挂起载荷；协调器只触碰线程安全的授权存储与值类型结果。
final class ComputerUseAuthorizationCoordinator: SuperLog, @unchecked Sendable {
    static let shared = ComputerUseAuthorizationCoordinator()

    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.computer-use",
        category: "ComputerUseAuthorization"
    )
    nonisolated static let verbose = false

    private let authorization: ComputerUseAuthorizationStore

    init(authorization: ComputerUseAuthorizationStore = .shared) {
        self.authorization = authorization
    }

    // MARK: - 请求方向

    /// 构造一个挂起用的授权请求结果。
    ///
    /// 返回 `awaitingUserResponse: true` 会让 AgentLoop 创建 suspension 并暂停回合，
    /// 卡片随后出现在消息列表中。
    func pendingResult(
        applicationName: String,
        bundleIdentifier: String,
        operation: String
    ) -> ToolCallResult {
        let request = ComputerUseAuthorizationRequest(
            applicationName: applicationName,
            bundleIdentifier: bundleIdentifier,
            operation: operation
        )
        let payload = AuthorizationPayload(
            kind: ComputerUseAuthorizationRequest.kind,
            request: request,
            options: ComputerUseAuthorizationDecision.allCases.map(\.rawValue)
        )
        guard let data = try? JSONEncoder().encode(payload),
              let content = String(data: data, encoding: .utf8) else {
            // 编码失败时不能让回合永久挂起：退回一个明确的错误结果。
            return ToolCallResult(
                content: pluginLocalization.string("Failed to create the Computer Use authorization request."),
                isError: true
            )
        }
        if Self.verbose {
            Self.logger.info(
                "\(Self.t)挂起授权请求 app=\(bundleIdentifier, privacy: .public)"
            )
        }
        return ToolCallResult(
            content: content,
            isError: false,
            awaitingUserResponse: true,
            interactionState: .waiting
        )
    }

    // MARK: - 决策方向

    /// 落地上下文中的用户决策。
    ///
    /// - Returns: 回传给 agent 的结果文本。
    func apply(
        decision: ComputerUseAuthorizationDecision,
        request: ComputerUseAuthorizationRequest
    ) -> String {
        switch decision {
        case .allowOnce:
            authorization.grantOneShot(bundleIdentifier: request.bundleIdentifier)
            if Self.verbose {
                Self.logger.info(
                    "\(Self.t)授予一次性授权 app=\(request.bundleIdentifier, privacy: .public)"
                )
            }
            return ComputerUseAuthorizationResolver.allowOnceMessage(
                applicationName: request.applicationName
            )
        case .alwaysAllow:
            // 与设置界面的「允许」写入同一份白名单，两条路径共用同一存储。
            authorization.setAllowed(true, bundleIdentifier: request.bundleIdentifier)
            if Self.verbose {
                Self.logger.info(
                    "\(Self.t)授予持久授权 app=\(request.bundleIdentifier, privacy: .public)"
                )
            }
            return ComputerUseAuthorizationResolver.alwaysAllowMessage(
                applicationName: request.applicationName
            )
        case .deny:
            if Self.verbose {
                Self.logger.info(
                    "\(Self.t)用户拒绝 app=\(request.bundleIdentifier, privacy: .public)"
                )
            }
            return ComputerUseAuthorizationResolver.denialMessage(
                applicationName: request.applicationName
            )
        }
    }

    /// 从 tool result 内容中解析授权请求。
    ///
    /// 工具被重新执行时，需要从上一次挂起留下的载荷里读出目标应用。
    func request(from content: String) -> ComputerUseAuthorizationRequest? {
        guard let data = content.data(using: .utf8),
              let payload = try? JSONDecoder().decode(AuthorizationPayload.self, from: data),
              payload.kind == ComputerUseAuthorizationRequest.kind else {
            return nil
        }
        return payload.request
    }
}

/// 授权请求在 tool result 中的编码结构。
///
/// 与 `ToolApprovalBridge` 的 `ToolPermissionRequest` 保持同样的形状：
/// `kind` 用来区分载荷类型，`options` 列出合法的决策取值。
struct AuthorizationPayload: Codable, Equatable, Sendable {
    let kind: String
    let request: ComputerUseAuthorizationRequest
    let options: [String]

    enum CodingKeys: String, CodingKey {
        case kind, request, options
    }
}
