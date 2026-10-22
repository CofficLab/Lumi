import Foundation
import KitAgentTool

/// Computer Use 工具的授权挂起包装。
///
/// 把「服务层抛出 `authorizationRequired`」转换成「挂起回合等待用户授权」。
///
/// 挂起后 AgentLoop 会创建 suspension 并暂停回合，用户在消息列表的授权卡片
/// 上做出决定；回合恢复时工具会被**重新执行**一次，此时授权已经生效，
/// 服务层直接放行。
///
/// - Note: 本类型只负责协议层的挂起转换，不参与任何判定。
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
            guard case let .authorizationRequired(applicationName, bundleIdentifier, operationName) = error else {
                // 非授权类错误按普通失败处理：让 AgentLoop 拿到明确的错误结果。
                return ToolCallResult(
                    content: error.errorDescription ?? String(describing: error),
                    isError: true
                )
            }
            return coordinator.pendingResult(
                applicationName: applicationName,
                bundleIdentifier: bundleIdentifier,
                operation: operationName.isEmpty ? operation : operationName
            )
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