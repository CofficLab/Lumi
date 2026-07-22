import Foundation
import LumiKernel
import LumiKernel
import LumiKernel
import LumiKernel

/// Agent 工具服务实现
@MainActor
public final class ToolManagerService: ToolManaging {

    /// 已注册的工具
    private var registeredTools: [String: any LumiAgentTool] = [:]

    /// 工具注册顺序
    private var toolOrder: [String] = []

    public init() {}

    // MARK: - ToolManaging

    public func allAgentTools() -> [any LumiAgentTool] {
        toolOrder.compactMap { registeredTools[$0] }
    }

    public func add(_ tool: any LumiAgentTool) {
        if registeredTools[tool.name] == nil {
            toolOrder.append(tool.name)
        }
        registeredTools[tool.name] = tool
    }

    public func remove(id: String) {
        registeredTools.removeValue(forKey: id)
        toolOrder.removeAll { $0 == id }
    }

    public func allSubAgents() -> [LumiSubAgentDefinition] {
        []
    }

    public func addSubAgent(_ subAgent: LumiSubAgentDefinition) {}

    public func collectTools() async throws -> [any LumiAgentTool] {
        allAgentTools()
    }

    public func executeTool(name: String, arguments: String, context: LumiToolExecutionContext) async throws -> String {
        guard let tool = registeredTools[name] else {
            throw AgentToolError.toolNotFound(name: name)
        }

        // 解析参数 JSON
        var argumentsDict: [String: LumiJSONValue] = [:]
        if let data = arguments.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            argumentsDict = Self.convertToLumiJSONValue(json)
        }

        return try await tool.execute(arguments: argumentsDict, context: context)
    }

    // MARK: - JSON Conversion

    private static func convertToLumiJSONValue(_ dict: [String: Any]) -> [String: LumiJSONValue] {
        dict.mapValues { value -> LumiJSONValue in
            convertValueToLumiJSONValue(value)
        }
    }

    private static func convertValueToLumiJSONValue(_ value: Any) -> LumiJSONValue {
        switch value {
        case let s as String: return .string(s)
        case let n as Int: return .int(n)
        case let n as Double: return .double(n)
        case let b as Bool: return .bool(b)
        case let arr as [Any]:
            return .array(arr.map { convertValueToLumiJSONValue($0) })
        case let obj as [String: Any]:
            return .object(convertToLumiJSONValue(obj))
        case is NSNull: return .null
        default: return .null
        }
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