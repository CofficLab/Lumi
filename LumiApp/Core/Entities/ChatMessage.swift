import Foundation

/// 聊天消息模型
struct ChatMessage: Identifiable, Codable, Sendable, Equatable {
    /// 消息唯一标识符
    let id: UUID

    /// 消息发送者角色
    let role: MessageRole

    /// 所属会话 ID（必填）。
    let conversationId: UUID

    /// 消息内容
    var content: String

    /// 消息时间戳
    let timestamp: Date

    /// 是否为错误消息
    var isError: Bool = false

    /// 工具调用列表
    var toolCalls: [ToolCall]?

    /// 工具调用 ID
    var toolCallID: String?

    /// 图片附件列表
    var images: [ImageAttachment] = []

    /// LLM 供应商 ID
    var providerId: String?

    /// 模型名称
    var modelName: String?

    /// 请求延迟（毫秒）
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

    /// 完成原因（stop/max_tokens/tool_calls 等）
    var finishReason: String?

    /// 供应商请求 ID（用于问题追踪）
    var requestId: String?

    /// 生成时使用的 temperature 参数
    var temperature: Double?

    /// 生成时使用的 max_tokens 参数
    var maxTokens: Int?

    /// 思考过程文本
    var thinkingContent: String?

    /// 原始错误详情（如 HTTP 状态码、响应体等），用于在 UI 底部折叠展示
    var rawErrorDetail: String?

    /// 是否为临时状态消息（用于 UI 展示"连接中/等待响应/生成中"等）
    var isTransientStatus: Bool = false

    /// 消息队列状态（仅用于消息发送队列管理）
    /// - nil: 不在队列中（历史消息或已完成发送的消息）
    /// - pending: 待发送
    /// - processing: 处理中
    var queueStatus: MessageQueueStatus?

    /// 是否应该发送到 LLM 作为对话上下文的一部分
    var shouldSendToLLM: Bool {
        switch role {
        case .user, .assistant, .tool:
            return true
        case .system, .status, .error, .unknown:
            return false
        }
    }

    /// 是否应该在气泡下方展示消息工具栏（复制/操作按钮行等）
    /// 统一在模型层收敛 UI 规则，避免各处散落判断。
    var shouldShowToolbar: Bool {
        switch role {
        case .user, .assistant:
            return true
        case .system, .status, .tool, .unknown:
            return false
        case .error:
            return true
        }
    }

    /// 是否为工具输出消息（由工具执行产生的消息）
    var isToolOutput: Bool {
        toolCallID != nil
    }

    /// 是否包含工具调用（assistant 发起的 Tool Call 列表）
    var hasToolCalls: Bool {
        !(toolCalls?.isEmpty ?? true)
    }

    /// 是否包含可发送内容（文本或图片）
    var hasSendableContent: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !images.isEmpty
    }

    /// 是否应展示在聊天消息列表中
    func shouldDisplayInChatList() -> Bool {
        switch role {
        case .user, .assistant:
            return true
        case .tool:
            return false
        case .status, .error:
            return true
        case .system, .unknown:
            return false
        }
    }

    /// 判断是否为请求超时错误（含被 APIError.requestFailed 包装的 URLError.timedOut）。
    static func isTimeoutError(_ error: Error) -> Bool {
        let nse = error as NSError
        if nse.domain == NSURLErrorDomain && nse.code == NSURLErrorTimedOut { return true }
        if let apiError = error as? APIError, case let .requestFailed(underlying) = apiError {
            let inner = underlying as NSError
            return inner.domain == NSURLErrorDomain && inner.code == NSURLErrorTimedOut
        }
        return false
    }

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
    init(role: MessageRole, conversationId: UUID, content: String, isError: Bool = false,
         toolCalls: [ToolCall]? = nil, toolCallID: String? = nil,
         images: [ImageAttachment] = [],
         providerId: String? = nil, modelName: String? = nil,
         latency: Double? = nil, inputTokens: Int? = nil,
         outputTokens: Int? = nil, totalTokens: Int? = nil,
         timeToFirstToken: Double? = nil, streamingDuration: Double? = nil,
         thinkingDuration: Double? = nil, finishReason: String? = nil,
         requestId: String? = nil, temperature: Double? = nil,
         maxTokens: Int? = nil, thinkingContent: String? = nil,
         rawErrorDetail: String? = nil,
         isTransientStatus: Bool = false,
         queueStatus: MessageQueueStatus? = nil) {
        self.id = UUID()
        self.role = role
        self.conversationId = conversationId
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
        self.rawErrorDetail = rawErrorDetail
        self.isTransientStatus = isTransientStatus
        self.queueStatus = queueStatus
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
    init(id: UUID, role: MessageRole, conversationId: UUID, content: String, timestamp: Date,
         isError: Bool = false, toolCalls: [ToolCall]? = nil,
         toolCallID: String? = nil, images: [ImageAttachment] = [],
         providerId: String? = nil, modelName: String? = nil,
         latency: Double? = nil, inputTokens: Int? = nil,
         outputTokens: Int? = nil, totalTokens: Int? = nil,
         timeToFirstToken: Double? = nil, streamingDuration: Double? = nil,
         thinkingDuration: Double? = nil, finishReason: String? = nil,
         requestId: String? = nil, temperature: Double? = nil,
         maxTokens: Int? = nil, thinkingContent: String? = nil,
         rawErrorDetail: String? = nil,
         isTransientStatus: Bool = false,
         queueStatus: MessageQueueStatus? = nil) {
        self.id = id
        self.role = role
        self.conversationId = conversationId
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
        self.rawErrorDetail = rawErrorDetail
        self.isTransientStatus = isTransientStatus
        self.queueStatus = queueStatus
    }

    // MARK: - Equatable

    /// 比较两条消息是否相等
    ///
    /// 基于 ID、角色、内容、错误状态、图片、供应商和延迟进行比较。
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id &&
            lhs.role == rhs.role &&
            lhs.conversationId == rhs.conversationId &&
            lhs.content == rhs.content &&
            lhs.isError == rhs.isError &&
            lhs.toolCalls == rhs.toolCalls &&
            lhs.images == rhs.images &&
            lhs.providerId == rhs.providerId &&
            lhs.modelName == rhs.modelName &&
            lhs.latency == rhs.latency &&
            lhs.isTransientStatus == rhs.isTransientStatus &&
            lhs.queueStatus == rhs.queueStatus
    }
}
