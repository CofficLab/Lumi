import Foundation
import LumiKernel

/// Agent 工具信息
public struct AgentToolInfoImpl: AgentToolInfo, Sendable {
    public let name: String
    public let description: String

    public init(name: String, description: String) {
        self.name = name
        self.description = description
    }
}

/// Agent 工具服务实现
@MainActor
public final class AgentToolService: AgentToolProviding {

    /// 已注册的工具
    private var registeredTools: [String: AgentToolInfoImpl] = [:]

    /// 工具执行器
    private var executors: [String: @MainActor @Sendable (String) async throws -> String] = [:]

    public init() {}

    // MARK: - Tool Registration

    /// 注册工具
    public func registerTool(
        _ tool: AgentToolInfoImpl,
        executor: @MainActor @Sendable @escaping (String) async throws -> String
    ) {
        registeredTools[tool.name] = tool
        executors[tool.name] = executor
    }

    /// 注销工具
    public func unregisterTool(name: String) {
        registeredTools.removeValue(forKey: name)
        executors.removeValue(forKey: name)
    }

    // MARK: - AgentToolProviding

    public func collectTools() async throws -> [any AgentToolInfo] {
        Array(registeredTools.values)
    }

    public func executeTool(name: String, arguments: String) async throws -> String {
        guard let executor = executors[name] else {
            throw AgentToolError.toolNotFound(name: name)
        }
        return try await executor(arguments)
    }
}

// MARK: - Errors

/// Agent 工具错误
public enum AgentToolError: Error, LocalizedError {
    case toolNotFound(name: String)
    case executionFailed(name: String, reason: String)

    public var errorDescription: String? {
        switch self {
        case .toolNotFound(let name):
            return "Tool '\(name)' not found"
        case .executionFailed(let name, let reason):
            return "Tool '\(name)' execution failed: \(reason)"
        }
    }
}