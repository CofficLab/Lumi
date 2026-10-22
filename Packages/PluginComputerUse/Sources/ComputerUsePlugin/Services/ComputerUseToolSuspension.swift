import Foundation
import KitAgentTool

/// Computer Use 工具的失败转换层。
///
/// 把服务层抛出的错误转换成 AgentLoop 能消费的工具结果，三条路径：
/// 1. `authorizationRequired` → **挂起回合**等待用户在聊天里授权；
/// 2. `accessibilityPermissionRequired` / `screenRecordingPermissionRequired`
///    → **带结构化载荷的失败结果**（不挂起），渲染层据此渲染系统权限提示卡；
/// 3. 其它错误 → 普通失败结果。
///
/// 挂起后 AgentLoop 会创建 suspension 并暂停回合，用户在消息列表的授权卡片
/// 上做出决定；回合恢复时工具会被**重新执行**一次，此时授权已经生效，
/// 服务层直接放行。
///
/// - Note: 系统权限缺失**不挂起**：用户无法在聊天里授予 macOS TCC 权限，
///   只能跳转系统设置。挂起会让回合永远等一个不会到来的回答。
/// - Note: 本类型只负责协议层的结果转换，不参与任何判定。
///   放行与否由 `ComputerUseAccessChecker` 统一决定。
enum ComputerUseToolSuspension {
    /// 执行工具主体，把授权请求转换成挂起结果。
    ///
    /// - Parameters:
    ///   - operation: 面向用户的操作描述，显示在卡片上。
    ///   - body: 真正的工具执行体。
    /// - Returns: 正常完成时返回工具结果；需要授权时返回挂起结果。
    static func execute(
        operation: String,
        body: () async throws -> ToolCallResult
    ) async -> ToolCallResult {
        await execute(operation: operation, coordinator: .shared, body: body)
    }

    /// 注入协调器的执行入口，供测试隔离运行时目录。
    ///
    /// 协调器默认取 `.shared`，它会经由 `ComputerUseAuthorizationStore.shared`
    /// 触碰运行时目录；测试进程必须避开这一点。
    static func execute(
        operation: String,
        coordinator: ComputerUseAuthorizationCoordinator,
        body: () async throws -> ToolCallResult
    ) async -> ToolCallResult {
        do {
            return try await body()
        } catch let error as ComputerUseError {
            switch error {
            case let .authorizationRequired(applicationName, bundleIdentifier, operationName):
                return coordinator.pendingResult(
                    applicationName: applicationName,
                    bundleIdentifier: bundleIdentifier,
                    operation: operationName.isEmpty ? operation : operationName
                )
            case .accessibilityPermissionRequired:
                // 系统权限无法在聊天里决定，只能引导用户去系统设置。
                // 返回带载荷的失败结果（不挂起回合），渲染层据此渲染提示卡。
                return ComputerUseSystemPermissionCoordinator.failureResult(
                    permission: .accessibility,
                    operation: operation
                )
            case .screenRecordingPermissionRequired:
                return ComputerUseSystemPermissionCoordinator.failureResult(
                    permission: .screenRecording,
                    operation: operation
                )
            default:
                // 非授权类错误按普通失败处理：让 AgentLoop 拿到明确的错误结果。
                return ToolCallResult(
                    content: error.errorDescription ?? String(describing: error),
                    isError: true
                )
            }
        } catch {
            return ToolCallResult(
                content: error.localizedDescription,
                isError: true
            )
        }
    }
}

extension SuperAgentTool where Self: ComputerUseSuspendingTool {
    /// 默认的挂起执行实现：捕获授权请求并挂起回合。
    public func executeWithAuthorizationSuspension(
        operation: String,
        body: () async throws -> ToolCallResult
    ) async -> ToolCallResult {
        await ComputerUseToolSuspension.execute(operation: operation, body: body)
    }
}

/// 标记支持聊天内授权挂起的工具。
///
/// 提供这个约束是为了让协议扩展只在真正实现了挂起语义的工具上可见，
/// 避免给所有 `SuperAgentTool` 暴露一个可能被误用的入口。
public protocol ComputerUseSuspendingTool: SuperAgentTool {}