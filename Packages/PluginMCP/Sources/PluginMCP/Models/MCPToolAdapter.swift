import Foundation
import KitAgentTool
import KitMCP

/// 把 MCP 服务器暴露的一个工具桥接为 Lumi 的 `SuperAgentTool`。
///
/// - 名称：`{serverID}.{toolName}`，保证跨服务器全局唯一；
///   点号命名经 `LLMToolNameSanitizer` 转义后对 LLM 可见，反查映射还原后按原名调度。
/// - 风险：委托 `MCPPermissionPolicy`（含用户单工具覆盖）。
/// - 执行：`session.callTool` → `ToolCallResult`（文本 / 图片）。
public struct MCPToolAdapter: SuperAgentTool {
    /// 命名空间后的注册名：`{serverID}.{toolName}`。
    public let name: String
    /// 所属服务器 id（命名空间前缀）。
    public let serverID: String
    /// 服务器原始工具描述。
    public let descriptor: MCPToolDescriptor
    /// 服务器显示名（用于描述文案）。
    public let serverName: String
    /// 底层 MCP 会话（KitMCP 薄抽象）。
    public let session: any MCPServerServing
    /// 风险分级策略。
    public let policy: MCPPermissionPolicy
    /// 用户单工具风险覆盖。
    public let riskOverride: CommandRiskLevel?

    public init(
        serverID: String,
        serverName: String,
        descriptor: MCPToolDescriptor,
        session: any MCPServerServing,
        policy: MCPPermissionPolicy,
        riskOverride: CommandRiskLevel? = nil
    ) {
        self.serverID = serverID
        self.serverName = serverName
        self.descriptor = descriptor
        self.session = session
        self.policy = policy
        self.riskOverride = riskOverride
        self.name = "\(serverID).\(descriptor.name)"
    }

    // MARK: - SuperAgentTool

    public func description(for language: LanguagePreference) -> String {
        let raw = descriptor.description?.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = raw?.isEmpty == false ? raw! : "MCP tool from server \(serverName)"
        return "[\(serverName)] \(base)"
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        descriptor.inputSchemaDictionary() ?? ["type": "object", "properties": [:]]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        let tool = descriptor.name
        let keys = arguments.keys.sorted().prefix(3).joined(separator: ", ")
        return keys.isEmpty
            ? "调用 MCP 工具 \(tool)（\(serverName)）"
            : "调用 MCP 工具 \(tool)（\(serverName)，参数 \(keys)）"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        policy.level(for: descriptor, override: riskOverride)
    }

    /// 只读工具（注解 readOnlyHint 且策略判定为 safe/low）可并行；其余串行。
    public var executionCapability: ToolExecutionCapability {
        let level = policy.level(for: descriptor, override: riskOverride)
        if descriptor.readOnlyHint == true, level == .safe || level == .low {
            return .parallelReadOnly
        }
        return .serialSideEffect
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        try await executeResult(context: .dummy, arguments: arguments).content
    }

    public func executeResult(
        context: ToolExecutionContext,
        arguments: [String: ToolArgument]
    ) async throws -> ToolCallResult {
        guard let payload = MCPJSONValue.fromFoundation(arguments.mapValues(\.value)) else {
            throw ToolExecutionError.executionFailed(
                toolName: name,
                reason: "参数包含无法 JSON 序列化的值，已拒绝调用以保护参数完整性。"
            )
        }
        guard case .object(let values) = payload else {
            throw ToolExecutionError.executionFailed(
                toolName: name,
                reason: "参数不是 JSON 对象。"
            )
        }
        let mcpArguments = values

        do {
            let result = try await session.callTool(name: descriptor.name, arguments: mcpArguments)
            var mapped = MCPToolAdapter.mapResult(result)
            if result.isError, let hint = MCPToolAdapter.friendlyHint(for: result.text) {
                mapped = ToolCallResult(
                    content: "\(result.text)\n\n💡 \(hint)",
                    images: mapped.images,
                    isError: true
                )
            }
            return mapped
        } catch let error as MCPClientError {
            throw ToolExecutionError.executionFailed(
                toolName: name,
                reason: "MCP 调用失败：\(Self.describe(error))"
            )
        } catch {
            throw ToolExecutionError.executionFailed(
                toolName: name,
                reason: "MCP 调用失败：\(error.localizedDescription)"
            )
        }
    }

    // MARK: - Error Hints

    /// 把服务器返回的已知错误模式翻译成可操作的中文提示（保留原文，追加建议）。
    /// 覆盖实测的 Xcode mcpbridge 故障路径：未授权 / 等待批准 / 未打开工作区。
    public static func friendlyHint(for text: String) -> String? {
        let lower = text.lowercased()
        if lower.contains("isn't approved") || lower.contains("not approved")
            || lower.contains("approve this agent") || lower.contains("approve this request") {
            return "尚未获得 Xcode 授权。先在 Lumi 的 MCP 设置中启用该服务器，并通过工具打开 Xcode 工程以触发授权，再在 Xcode 菜单栏的 MCP 图标中批准访问。"
        }
        if lower.contains("waiting for the user to approve") || lower.contains("pending approvals") {
            return "Xcode 正在等待你批准：请在 Xcode 菜单栏的 MCP 图标中批准本 Agent 与工程文件夹访问，然后重试。"
        }
        if lower.contains("no workspace") || lower.contains("no project")
            || lower.contains("open workspaces: none") || lower.contains("must open") {
            return "当前没有打开的 Xcode 工作区。请先用工具打开工程（XcodeOpenWorkspace），或手动在 Xcode 中打开工程后重试。"
        }
        return nil
    }

    // MARK: - Mapping

    /// `MCPCallResult` → `ToolCallResult`（文本 / 图片附件 / isError 透传）。
    public static func mapResult(_ result: MCPCallResult) -> ToolCallResult {
        ToolCallResult(
            content: result.text,
            images: result.images.compactMap { image in
                guard let data = Data(base64Encoded: image.base64Data) else { return nil }
                return ImageAttachment(data: data, mimeType: image.mimeType)
            },
            isError: result.isError
        )
    }

    private static func describe(_ error: MCPClientError) -> String {
        switch error {
        case .invalidConfiguration(let message):
            return "配置无效：\(message)"
        case .notConnected:
            return "服务器未连接"
        case .processSpawnFailed(let message):
            return "进程启动失败：\(message)"
        case .serverTerminated(let code):
            return "服务器进程已退出（码 \(code)）"
        case .transport(let message):
            return "传输错误：\(message)"
        }
    }
}

private extension ToolExecutionContext {
    /// 仅供 `execute(arguments:)` 兼容旧接口使用；实际调度走 context 版本。
    static var dummy: ToolExecutionContext {
        ToolExecutionContext(jobID: "mcp", conversationID: UUID())
    }
}
