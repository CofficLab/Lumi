import Foundation
import MCP

/// MCP 服务器暴露的一个工具（与 UI 无关的描述模型）。
public struct MCPToolDescriptor: Sendable, Equatable {
    /// 服务器原始工具名（不含命名空间前缀）。
    public let name: String
    /// 展示用标题（可选）。
    public let title: String?
    /// 工具描述（供 LLM 理解用途）。
    public let description: String?
    /// inputSchema 的 JSON 字符串（`{ "type": "object", ... }`）。
    /// 上层需要 `[String: Any]` 时用 `inputSchemaDictionary()` 解析。
    public let inputSchemaJSON: String
    /// 注解提示：只读（重复调用无副作用提示）。
    public let readOnlyHint: Bool?
    /// 注解提示：是否可能破坏性修改环境。
    public let destructiveHint: Bool?
    /// 注解提示：是否幂等。
    public let idempotentHint: Bool?
    /// 注解提示：是否与"开放世界"（外部实体）交互。
    public let openWorldHint: Bool?

    public init(
        name: String,
        title: String? = nil,
        description: String? = nil,
        inputSchemaJSON: String = "{}",
        readOnlyHint: Bool? = nil,
        destructiveHint: Bool? = nil,
        idempotentHint: Bool? = nil,
        openWorldHint: Bool? = nil
    ) {
        self.name = name
        self.title = title
        self.description = description
        self.inputSchemaJSON = inputSchemaJSON
        self.readOnlyHint = readOnlyHint
        self.destructiveHint = destructiveHint
        self.idempotentHint = idempotentHint
        self.openWorldHint = openWorldHint
    }

    /// 从 SDK 的 `Tool` 构造。
    public init(tool: Tool) {
        self.init(
            name: tool.name,
            title: tool.title,
            description: tool.description,
            inputSchemaJSON: MCPJSONValue(from: tool.inputSchema).jsonString() ?? "{}",
            readOnlyHint: tool.annotations.readOnlyHint,
            destructiveHint: tool.annotations.destructiveHint,
            idempotentHint: tool.annotations.idempotentHint,
            openWorldHint: tool.annotations.openWorldHint
        )
    }

    /// 解析 schema 为 `[String: Any]`（供 `SuperAgentTool.inputSchema` 使用）。
    public func inputSchemaDictionary() -> [String: Any]? {
        guard
            let data = inputSchemaJSON.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return object
    }
}
