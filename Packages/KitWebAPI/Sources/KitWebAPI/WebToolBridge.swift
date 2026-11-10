import Foundation
import KitAgentTool
import ProviderToolManager
import ProviderWebServer

// MARK: - Tool Descriptor

/// 一个 Agent Tool 的可序列化描述。
///
/// 让外部调用方在不执行工具的前提下，先知道「有哪些工具、参数长什么样」。
/// `schema` 保留工具自报的 JSON Schema 原始结构（`[String: Any]` 无法直接
/// `Encodable`，故用 `JSONValue` 包装）。
public struct WebToolDescriptor: Encodable, Sendable {
    /// 工具名称（唯一）。
    public let name: String
    /// 归属插件 ID。
    public let pluginID: String
    /// 工具描述（英文）。
    public let description: String
    /// 输入参数的 JSON Schema。
    public let schema: JSONValue
    /// 工具声明的执行能力（串行 / 并行只读）。
    public let executionCapability: String

    public init(
        name: String,
        pluginID: String,
        description: String,
        schema: JSONValue,
        executionCapability: String
    ) {
        self.name = name
        self.pluginID = pluginID
        self.description = description
        self.schema = schema
        self.executionCapability = executionCapability
    }
}

// MARK: - JSON Value

/// 可 `Encodable` / `Decodable` 的 JSON 值。
///
/// 工具的 `inputSchema` 是 `[String: Any]`，无法直接编码。`JSONValue` 把
/// 任意 JSON 兼容值转成可编码的树，同时拒绝非 JSON 类型（如 `Date`），
/// 避免编码时崩溃。
public enum JSONValue: Codable, Sendable, Equatable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    /// 把任意值转换为 JSON 值。
    ///
    /// - Parameter value: 任意值。非 JSON 类型一律降级为 `null`。
    public init(from value: Any) {
        switch value {
        case let value as Bool:
            self = .bool(value)
        case let value as Int:
            self = .number(Double(value))
        case let value as Double:
            self = .number(value)
        case let value as NSNumber:
            // `NSNumber` 同时匹配 Bool 与数字，需显式区分。
            if CFGetTypeID(value) == CFBooleanGetTypeID() {
                self = .bool(value.boolValue)
            } else {
                self = .number(value.doubleValue)
            }
        case let value as String:
            self = .string(value)
        case let value as [Any]:
            self = .array(value.map { JSONValue(from: $0) })
        case let value as [String: Any]:
            self = .object(value.mapValues { JSONValue(from: $0) })
        default:
            self = .null
        }
    }

    /// 从 JSON Schema 字典构建。
    public init(schema: [String: Any]) {
        self = JSONValue(from: schema)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Value is not a valid JSON value"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let values):
            try container.encode(values)
        case .object(let values):
            try container.encode(values)
        }
    }
}

// MARK: - Tool Execution Result

/// 一次工具调用的结果。
public struct WebToolExecutionResult: Encodable, Sendable {
    /// 工具名称。
    public let tool: String
    /// 结果文本。
    public let content: String
    /// 是否为错误结果。
    public let isError: Bool
    /// 执行耗时（秒）。
    public let duration: TimeInterval?
    /// 是否处于「等待用户响应」的挂起状态。
    public let awaitingUserResponse: Bool

    /// 结果中的图片附件（字节、MIME 类型与文件名）。
    ///
    /// `read_image` 这类工具的主要结果就是图片；HTTP 调用方需要拿到真实
    /// 附件，而不是只看到一句「图片已附加」的正文。
    public let images: [ImageAttachment]

    public init(
        tool: String,
        content: String,
        isError: Bool,
        duration: TimeInterval?,
        awaitingUserResponse: Bool,
        images: [ImageAttachment] = []
    ) {
        self.tool = tool
        self.content = content
        self.isError = isError
        self.duration = duration
        self.awaitingUserResponse = awaitingUserResponse
        self.images = images
    }

    private enum CodingKeys: String, CodingKey {
        case tool, content, isError, duration, awaitingUserResponse, images
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(tool, forKey: .tool)
        try container.encode(content, forKey: .content)
        try container.encode(isError, forKey: .isError)
        try container.encodeIfPresent(duration, forKey: .duration)
        try container.encode(awaitingUserResponse, forKey: .awaitingUserResponse)
        // 无图片时不输出空数组，保持既有标量响应形状不变。
        if !images.isEmpty { try container.encode(images, forKey: .images) }
    }
}

// MARK: - Tool Bridge

/// Agent Tool → HTTP 统一桥接器。
///
/// 把 `ToolManagerProviding` 里注册的工具暴露为 HTTP 端点：
/// - `GET  /api/v1/tools` —— 列出全部工具（含参数 schema）
/// - `GET  /api/v1/tools/:name` —— 查看单个工具的详情与 schema
/// - `POST /api/v1/tools/:name/invoke` —— 调用工具
///
/// 工具执行复用 `ToolManagerProviding.execute`，并在执行前调用
/// `authorizationDecision`，因此会话级策略（Chat 阻断、Build 高风险需确认）
/// 与正常 Agent 路径保持一致；HTTP 无法弹出授权界面，需要批准的调用直接拒绝。
///
/// - Note: 工具执行需要 `conversationID` 作为上下文（会话决定自动化等级与
///   项目路径）。调用方通过请求体 `conversationID` 指定；缺省时桥接器用
///   `fallbackConversationID` 兜底，或由 `conversationResolver` 动态解析。
@MainActor
public final class WebToolBridge {
    /// 工具管理器。
    private let toolManager: any ToolManagerProviding

    /// 工具归属插件的映射（工具名 → 插件 ID）。
    private var pluginIndex: [String: String]

    /// 缺省会话 ID。调用方未指定 `conversationID` 时使用。
    private let fallbackConversationID: UUID?

    /// 会话解析器。优先级高于 `fallbackConversationID`。
    private let conversationResolver: (@MainActor @Sendable () -> UUID?)?

    /// 创建桥接器。
    ///
    /// - Parameters:
    ///   - toolManager: 工具管理器。
    ///   - fallbackConversationID: 缺省会话 ID。
    ///   - conversationResolver: 会话解析器，优先于缺省值。
    public init(
        toolManager: any ToolManagerProviding,
        fallbackConversationID: UUID? = nil,
        conversationResolver: (@MainActor @Sendable () -> UUID?)? = nil
    ) {
        self.toolManager = toolManager
        self.pluginIndex = Self.buildPluginIndex(from: toolManager)
        self.fallbackConversationID = fallbackConversationID
        self.conversationResolver = conversationResolver
    }

    /// 从工具管理器构建「工具名 → 插件 ID」索引。
    private static func buildPluginIndex(from toolManager: any ToolManagerProviding) -> [String: String] {
        var index: [String: String] = [:]
        for (pluginID, tools) in toolManager.toolsGroupedByPlugin() {
            for tool in tools {
                index[tool.name] = pluginID
            }
        }
        return index
    }

    /// 刷新工具归属索引。
    ///
    /// 工具注册表会随插件启停、MCP 连接变化，描述查询前会自动调用；
    /// 外部观察到工具变化后也可主动调用。
    public func refresh() {
        pluginIndex = Self.buildPluginIndex(from: toolManager)
    }

    // MARK: - Descriptors

    /// 全部工具的描述列表。
    public func toolDescriptors() -> [WebToolDescriptor] {
        // 索引只在初始化时构建一次会漏掉之后注册的工具（插件启用、MCP 连接），
        // 导致这些工具的 pluginID 被误报为 Built-in。
        refresh()
        return toolManager.allTools().map { tool in
            WebToolDescriptor(
                name: tool.name,
                pluginID: pluginIndex[tool.name] ?? "Built-in",
                description: tool.description(for: .english),
                schema: JSONValue(schema: tool.inputSchema(for: .english)),
                executionCapability: Self.capabilityName(tool.executionCapability)
            )
        }
    }

    /// 单个工具的描述。
    ///
    /// - Parameter name: 工具名称。
    /// - Returns: 工具不存在时返回 `nil`。
    public func toolDescriptor(named name: String) -> WebToolDescriptor? {
        // 同 `toolDescriptors()`：查询前刷新，归属信息不能停留在初始化快照。
        refresh()
        guard let tool = toolManager.tool(named: name) else { return nil }
        return WebToolDescriptor(
            name: tool.name,
            pluginID: pluginIndex[tool.name] ?? "Built-in",
            description: tool.description(for: .english),
            schema: JSONValue(schema: tool.inputSchema(for: .english)),
            executionCapability: Self.capabilityName(tool.executionCapability)
        )
    }

    // MARK: - Execution

    /// 调用一个工具。
    ///
    /// - Parameters:
    ///   - name: 工具名称。
    ///   - arguments: 工具参数（JSON 兼容的字典）。
    ///   - conversationID: 会话 ID；为 `nil` 时用缺省值或解析器兜底。
    /// - Returns: 执行结果。
    /// - Throws: `WebAPIError`：工具不存在（404）、缺少会话上下文（400）。
    public func invoke(
        tool name: String,
        arguments: [String: Any],
        conversationID: UUID?
    ) async throws -> WebToolExecutionResult {
        guard toolManager.tool(named: name) != nil else {
            throw WebAPIError.notFound(message: "Tool not found: \(name)")
        }

        guard let resolvedConversationID = conversationID ?? resolveConversationID() else {
            throw WebAPIError.badRequest(
                message: "conversationID is required to invoke a tool",
                field: "conversationID"
            )
        }

        let toolCall = ToolCall(
            id: UUID().uuidString,
            name: name,
            arguments: Self.encodeArguments(arguments)
        )

        // HTTP 没有交互式授权通道，必须沿用会话的自动化策略：
        // Chat 直接拒绝；Build 中需要确认的调用不执行，由调用方在 Lumi 内确认。
        switch toolManager.authorizationDecision(for: toolCall, conversationID: resolvedConversationID) {
        case .autoApproved:
            break
        case .blocked(let reason):
            throw WebAPIError.forbidden(message: reason)
        case .requiresUserApproval:
            throw WebAPIError.forbidden(
                message: "Tool \(name) requires user approval in Lumi before it can be invoked over HTTP."
            )
        }

        let result = await toolManager.execute(
            toolCall,
            conversationID: resolvedConversationID,
            turnID: nil
        )

        return WebToolExecutionResult(
            tool: name,
            content: result.content,
            isError: result.isError,
            duration: result.duration,
            awaitingUserResponse: result.awaitingUserResponse,
            images: result.images
        )
    }

    /// 解析会话 ID。
    private func resolveConversationID() -> UUID? {
        if let conversationResolver {
            return conversationResolver()
        }
        return fallbackConversationID
    }

    /// 执行能力的对外名称。
    ///
    /// `ToolExecutionCapability` 没有 `RawRepresentable`，这里显式映射成
    /// 稳定的字符串，避免调用方依赖 Swift 枚举的 case 名。
    static func capabilityName(_ capability: ToolExecutionCapability) -> String {
        switch capability {
        case .serialSideEffect: return "serial_side_effect"
        case .parallelReadOnly: return "parallel_read_only"
        case .interactive: return "interactive"
        }
    }

    /// 把参数字典编码为 JSON 字符串。
    ///
    /// 工具参数本身是「JSON 兼容值」，因此直接用 `JSONSerialization`；
    /// 失败时退化为空对象，让工具收到「无参数」而不是崩溃。
    nonisolated static func encodeArguments(_ arguments: [String: Any]) -> String {
        guard !arguments.isEmpty else { return "{}" }
        guard JSONSerialization.isValidJSONObject(arguments),
              let data = try? JSONSerialization.data(withJSONObject: arguments),
              let string = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return string
    }
}
