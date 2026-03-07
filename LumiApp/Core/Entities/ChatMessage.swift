import Foundation

/// 聊天消息模型
///
/// 表示 Lumi 应用中的一条聊天消息。
/// 用于用户与 AI 助手之间的对话记录。
///
/// ## 消息类型
///
/// 消息根据角色 (`role`) 区分：
/// - `user`: 用户发送的消息
/// - `assistant`: AI 助手回复的消息
/// - `system`: 系统消息
///
/// ## 扩展功能
///
/// - **工具调用**: 支持 Tool Calls 功能，AI 可以请求执行工具
/// - **图片附件**: 支持在消息中附带图片
/// - **性能指标**: 记录请求延迟等信息
struct ChatMessage: Identifiable, Codable, Sendable, Equatable {
    /// 消息唯一标识符
    ///
    /// 使用 UUID 生成，确保每条消息有唯一 ID。
    let id: UUID
    
    /// 消息发送者角色
    ///
    /// 决定消息的显示样式和行为：
    /// - `.user`: 用户消息，右对齐显示
    /// - `.assistant`: AI 回复，左对齐显示
    /// - `.system`: 系统消息，居中显示
    let role: MessageRole
    
    /// 消息内容
    ///
    /// 支持 Markdown 格式的文本内容。
    var content: String
    
    /// 消息时间戳
    ///
    /// 消息创建的时间，用于显示和排序。
    let timestamp: Date
    
    /// 是否为错误消息
    ///
    /// 当 AI 返回错误或请求被拒绝时设为 true。
    /// UI 会用红色样式显示错误消息。
    var isError: Bool = false

    // MARK: - Tool Use Support
    
    /// 工具调用列表
    ///
    /// 当 AI 需要执行工具时，会生成 ToolCall 对象。
    /// 包含工具名称、参数等信息。
    /// - 何时使用: AI 请求执行函数调用时
    /// - 处理方式: UI 显示工具调用卡片，结果返回给 AI
    var toolCalls: [ToolCall]?
    
    /// 工具调用 ID
    ///
    /// 用于关联工具调用的请求和响应。
    var toolCallID: String?

    // MARK: - Image Support
    
    /// 图片附件列表
    ///
    /// 支持在消息中附带图片（目前主要用于视觉模型）。
    /// - 何时使用: 用户上传图片或 AI 回复包含图片时
    var images: [ImageAttachment] = []

    // MARK: - LLM Metadata
    
    /// LLM 供应商 ID
    ///
    /// 记录生成此消息的 LLM 供应商。
    /// 例如："anthropic", "openai", "zhipu", "deepseek"
    var providerId: String?
    
    /// 模型名称
    ///
    /// 记录生成此消息的具体模型。
    /// 例如："claude-sonnet-4-20250514", "gpt-4o"
    var modelName: String?

    // MARK: - Performance Metrics

    /// 请求延迟（毫秒）
    ///
    /// 从发送请求到收到响应的时间。
    /// 用于性能分析和用户展示。
    var latency: Double?

    /// 输入 token 数量
    var inputTokens: Int?

    /// 输出 token 数量
    var outputTokens: Int?

    /// 总 token 数量
    var totalTokens: Int?

    /// 首 token 延迟（毫秒）
    var timeToFirstToken: Double?

    /// 流式传输耗时（毫秒）
    var streamingDuration: Double?

    /// 思考过程耗时（毫秒）
    var thinkingDuration: Double?

    // MARK: - Request Metadata

    /// 完成原因（stop/max_tokens/tool_calls 等）
    var finishReason: String?

    /// 供应商请求 ID（用于问题追踪）
    var requestId: String?

    /// 生成时使用的 temperature 参数
    var temperature: Double?

    /// 生成时使用的 max_tokens 参数
    var maxTokens: Int?

    // MARK: - Thinking Process

    /// 思考过程文本
    ///
    /// 用于 reasoning 模型（如 Claude 3.7 Sonnet）的思考过程展示。
    /// 包含模型在生成最终回复前的思考内容。
    var thinkingContent: String?

    /// 初始化聊天消息
    ///
    /// - Parameters:
    ///   - role: 消息角色
    ///   - content: 消息内容
    ///   - isError: 是否为错误消息
    ///   - toolCalls: 工具调用列表
    ///   - toolCallID: 工具调用 ID
    ///   - images: 图片附件列表
    ///   - providerId: LLM 供应商 ID
    ///   - modelName: 模型名称
    ///   - latency: 请求延迟
    ///   - inputTokens: 输入 token 数量
    ///   - outputTokens: 输出 token 数量
    ///   - totalTokens: 总 token 数量
    ///   - timeToFirstToken: 首 token 延迟
    ///   - streamingDuration: 流式传输耗时
    ///   - thinkingDuration: 思考过程耗时
    ///   - finishReason: 完成原因
    ///   - requestId: 供应商请求 ID
    ///   - temperature: temperature 参数
    ///   - maxTokens: max_tokens 参数
    ///   - thinkingContent: 思考过程文本
    init(role: MessageRole, content: String, isError: Bool = false,
         toolCalls: [ToolCall]? = nil, toolCallID: String? = nil,
         images: [ImageAttachment] = [],
         providerId: String? = nil, modelName: String? = nil,
         latency: Double? = nil, inputTokens: Int? = nil,
         outputTokens: Int? = nil, totalTokens: Int? = nil,
         timeToFirstToken: Double? = nil, streamingDuration: Double? = nil,
         thinkingDuration: Double? = nil, finishReason: String? = nil,
         requestId: String? = nil, temperature: Double? = nil,
         maxTokens: Int? = nil, thinkingContent: String? = nil) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.isError = isError
        self.toolCalls = toolCalls
        self.toolCallID = toolCallID
        self.images = images
        self.providerId = providerId
        self.modelName = modelName
        self.latency = latency
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.totalTokens = totalTokens
        self.timeToFirstToken = timeToFirstToken
        self.streamingDuration = streamingDuration
        self.thinkingDuration = thinkingDuration
        self.finishReason = finishReason
        self.requestId = requestId
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.thinkingContent = thinkingContent
    }
    
    /// 从数据库加载时使用的初始化方法
    ///
    /// 保留原有 ID，用于从持久化存储加载消息。
    ///
    /// - Parameters:
    ///   - id: 消息 ID
    ///   - role: 消息角色
    ///   - content: 消息内容
    ///   - timestamp: 消息时间戳
    ///   - isError: 是否为错误消息
    ///   - toolCalls: 工具调用列表
    ///   - toolCallID: 工具调用 ID
    ///   - images: 图片附件列表
    ///   - providerId: LLM 供应商 ID
    ///   - modelName: 模型名称
    ///   - latency: 请求延迟
    ///   - inputTokens: 输入 token 数量
    ///   - outputTokens: 输出 token 数量
    ///   - totalTokens: 总 token 数量
    ///   - timeToFirstToken: 首 token 延迟
    ///   - streamingDuration: 流式传输耗时
    ///   - thinkingDuration: 思考过程耗时
    ///   - finishReason: 完成原因
    ///   - requestId: 供应商请求 ID
    ///   - temperature: temperature 参数
    ///   - maxTokens: max_tokens 参数
    ///   - thinkingContent: 思考过程文本
    init(id: UUID, role: MessageRole, content: String, timestamp: Date,
         isError: Bool = false, toolCalls: [ToolCall]? = nil,
         toolCallID: String? = nil, images: [ImageAttachment] = [],
         providerId: String? = nil, modelName: String? = nil,
         latency: Double? = nil, inputTokens: Int? = nil,
         outputTokens: Int? = nil, totalTokens: Int? = nil,
         timeToFirstToken: Double? = nil, streamingDuration: Double? = nil,
         thinkingDuration: Double? = nil, finishReason: String? = nil,
         requestId: String? = nil, temperature: Double? = nil,
         maxTokens: Int? = nil, thinkingContent: String? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isError = isError
        self.toolCalls = toolCalls
        self.toolCallID = toolCallID
        self.images = images
        self.providerId = providerId
        self.modelName = modelName
        self.latency = latency
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.totalTokens = totalTokens
        self.timeToFirstToken = timeToFirstToken
        self.streamingDuration = streamingDuration
        self.thinkingDuration = thinkingDuration
        self.finishReason = finishReason
        self.requestId = requestId
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.thinkingContent = thinkingContent
    }

    // MARK: - Equatable
    
    /// 比较两条消息是否相等
    ///
    /// 基于 ID、角色、内容、错误状态、图片、供应商和延迟进行比较。
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id &&
        lhs.role == rhs.role &&
        lhs.content == rhs.content &&
        lhs.isError == rhs.isError &&
        lhs.images == rhs.images &&
        lhs.providerId == rhs.providerId &&
        lhs.modelName == rhs.modelName &&
        lhs.latency == rhs.latency
    }
}