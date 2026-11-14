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
    ///
    /// 保留原始字符串以便持久化与比对；**上层需要 `[String: Any]` 时用
    /// `schema`**（已预解析，零成本）。
    public let inputSchemaJSON: String
    /// 注解提示：只读（重复调用无副作用提示）。
    public let readOnlyHint: Bool?
    /// 注解提示：是否可能破坏性修改环境。
    public let destructiveHint: Bool?
    /// 注解提示：是否幂等。
    public let idempotentHint: Bool?
    /// 注解提示：是否与"开放世界"（外部实体）交互。
    public let openWorldHint: Bool?

    /// 预解析的输入 schema。
    ///
    /// 工具 schema 在 `listTools` 之后是静态的，但此前每次访问
    /// `inputSchemaDictionary()` 都会重新解析同一段 JSON——每个 LLM 请求、
    /// 每次工具调用续轮都重来一遍（Issue #1275）。构造时解析一次，之后
    /// 访问零成本。
    public let schema: MCPToolSchema

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
        // 一次性解析：解析结果与规范化 JSON 文本都在这里算好。
        self.schema = MCPToolSchema(json: inputSchemaJSON)
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
    ///
    /// 现在直接返回构造时算好的结果，不再重新解析 JSON。
    public func inputSchemaDictionary() -> [String: Any]? {
        schema.parameters
    }

    /// 相等性只比较**原始描述字段**。
    ///
    /// `schema` 是从 `inputSchemaJSON` 推导出的缓存，由它决定；把它纳入
    /// 比较会让「同一个描述的两次构造」因缓存实例不同而不相等。
    public static func == (lhs: MCPToolDescriptor, rhs: MCPToolDescriptor) -> Bool {
        lhs.name == rhs.name
            && lhs.title == rhs.title
            && lhs.description == rhs.description
            && lhs.inputSchemaJSON == rhs.inputSchemaJSON
            && lhs.readOnlyHint == rhs.readOnlyHint
            && lhs.destructiveHint == rhs.destructiveHint
            && lhs.idempotentHint == rhs.idempotentHint
            && lhs.openWorldHint == rhs.openWorldHint
    }
}
