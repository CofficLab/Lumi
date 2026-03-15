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
    // MARK: - 内置系统消息内容标记
    ///
    /// 用于在 UI 中渲染专用视图的系统消息占位符内容。
    /// 这些特殊内容不会直接展示给用户，而是由 UI 组件识别后渲染对应的自定义视图。
    static let apiKeyMissingSystemContentKey = "__LUMI_API_KEY_MISSING__"
    /// 本地模型正在加载时的系统消息占位符，由 UI 渲染「正在加载模型」专用视图。
    static let loadingLocalModelSystemContentKey = "__LUMI_LOADING_LOCAL_MODEL__"
    /// 本地模型已就绪（加载完成）时的系统消息占位符，由 UI 渲染「模型已就绪」状态，不再显示加载动画。
    static let loadingLocalModelDoneSystemContentKey = "__LUMI_LOADING_LOCAL_MODEL_DONE__"
    /// 本地模型加载失败（如未下载）时的系统消息占位符，由 UI 渲染「加载失败」状态。
    static let loadingLocalModelFailedSystemContentKey = "__LUMI_LOADING_LOCAL_MODEL_FAILED__"
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

    // MARK: - UI Only (Non-persisted intent)

    /// 是否为临时状态消息（用于 UI 展示“连接中/等待响应/生成中”等）
    /// 注意：这类消息不应写入数据库。
    var isTransientStatus: Bool = false

    // MARK: - UI Convenience

    /// 是否应该在气泡下方展示消息工具栏（复制/操作按钮行等）
    /// 统一在模型层收敛 UI 规则，避免各处散落判断。
    var shouldShowToolbar: Bool {
        switch role {
        case .user, .assistant:
            return true
        case .system, .status, .tool:
            return false
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

    /// 是否应展示在聊天消息列表中
    func shouldDisplayInChatList() -> Bool {
        guard role.shouldDisplayInChatList else { return false }
        if isToolOutput { return true }
        return true
    }

    // MARK: - Factory Helpers

    /// 达到最大深度时的最后一步提醒（作为一条 user 消息追加，用于提示模型不再调用工具、直接给出最终回答）。
    static func maxDepthFinalStepReminderMessage() -> ChatMessage {
        ChatMessage(
            role: .user,
            content: """
            <system-reminder>
            You have reached the final execution step. Do not call any tools anymore.
            Provide your best final answer using the information already collected.
            If critical information is missing, explicitly state what is missing and ask one concise follow-up question.
            </system-reminder>
            """
        )
    }

    /// 系统因达到最大执行深度而终止本轮对话时，用于向用户解释原因的系统消息。
    static func maxDepthToolLimitMessage(languagePreference: LanguagePreference, currentDepth: Int, maxDepth: Int) -> ChatMessage {
        let content: String
        switch languagePreference {
        case .chinese:
            content = "由于系统限制，本轮对话已达到最大执行深度（\(currentDepth)/\(maxDepth)），后续的工具调用请求已被忽略。请调整问题或缩小任务范围后再试。"
        case .english:
            content = "Due to system safety limits, this turn has reached the maximum execution depth (\(currentDepth)/\(maxDepth)). Additional tool calls have been ignored and the conversation turn has been terminated. Please refine your question or narrow the task scope and try again."
        }
        return ChatMessage(
            role: .system,
            content: content,
            isError: true
        )
    }

    /// 检测到重复工具调用循环时，用于向用户解释原因的助手消息。
    static func repeatedToolLoopMessage(
        languagePreference: LanguagePreference,
        tool: ToolCall,
        repeatedCount: Int,
        windowCount: Int
    ) -> ChatMessage {
        // 尝试对参数做 JSON pretty-print，便于用户排查
        func formatArgs(_ raw: String) -> String {
            guard !raw.isEmpty,
                  raw != "{}",
                  let data = raw.data(using: .utf8),
                  let jsonObject = try? JSONSerialization.jsonObject(with: data) else {
                return raw
            }
            if let prettyData = try? JSONSerialization.data(
                withJSONObject: jsonObject,
                options: [.prettyPrinted, .sortedKeys]
            ), let pretty = String(data: prettyData, encoding: .utf8) {
                return pretty
            }
            return raw
        }

        let prettyArgs = formatArgs(tool.arguments)

        let content: String
        switch languagePreference {
        case .chinese:
            content = """
检测到工具 **\(tool.name)** 被多次以相同/高度相似的参数重复调用，疑似进入工具调用循环，本轮对话已被系统自动中止。

- 重复次数（连续计数）：\(repeatedCount)
- 重复次数（最近窗口内）：\(windowCount)
- 调用参数示例：
```json
\(prettyArgs)
```

建议你：
- 检查提示词中是否要求模型“不断重试同一个工具”
- 为工具调用增加明确的停止条件或上限
- 必要时缩小任务范围，改为多轮分步执行
"""
        case .english:
            content = """
The tool **\(tool.name)** has been repeatedly invoked with the same or highly similar arguments, indicating a possible tool invocation loop. This conversation turn has been automatically terminated for safety.

- Repeated count (consecutive): \(repeatedCount)
- Repeated count (within recent window): \(windowCount)
- Example arguments:
```json
\(prettyArgs)
```

Recommended actions:
- Check if your prompt tells the model to \"keep retrying\" the same tool
- Add clear stopping conditions or limits around the tool usage
- Consider splitting the task into smaller, sequential steps
"""
        }

        return ChatMessage(
            role: .assistant,
            content: content,
            isError: true
        )
    }

    /// 请求失败（如超时、网络错误）时，用于在对话中展示的助手错误消息。
    static func requestFailedMessage(languagePreference: LanguagePreference, error: Error) -> ChatMessage {
        let isTimeout = Self.isTimeoutError(error)
        let content: String
        if isTimeout {
            switch languagePreference {
            case .chinese:
                content = "请求超时，本轮已终止。请检查网络或稍后重试。"
            case .english:
                content = "Request timed out; this turn has been terminated. Please check your network or try again later."
            }
        } else {
            switch languagePreference {
            case .chinese:
                content = "请求失败，本轮已终止：\(error.localizedDescription)。请检查网络或稍后重试。"
            case .english:
                content = "Request failed; this turn has been terminated: \(error.localizedDescription). Please check your network or try again later."
            }
        }
        return ChatMessage(
            role: .assistant,
            content: content,
            isError: true
        )
    }

    /// 当前供应商未配置 API Key 时，用于在对话中展示的系统消息。
    /// 这条消息本身只携带一个内部内容标记，实际说明文案和配置 UI 由前端 SystemMessage 组件负责渲染。
    static func apiKeyMissingSystemMessage(languagePreference: LanguagePreference) -> ChatMessage {
        ChatMessage(
            role: .system,
            content: Self.apiKeyMissingSystemContentKey,
            isError: true
        )
    }

    /// 本地模型未就绪、即将自动加载时，用于在对话中展示的系统提示。
    /// 内容为占位键，由 SystemMessage 组件渲染专用「正在加载模型」视图；providerId/modelName 用于展示模型信息。
    static func loadingLocalModelSystemMessage(
        languagePreference: LanguagePreference,
        providerId: String? = nil,
        modelName: String? = nil
    ) -> ChatMessage {
        ChatMessage(
            role: .system,
            content: Self.loadingLocalModelSystemContentKey,
            providerId: providerId,
            modelName: modelName
        )
    }

    /// 判断是否为请求超时错误（含被 APIError.requestFailed 包装的 URLError.timedOut）。
    private static func isTimeoutError(_ error: Error) -> Bool {
        let nse = error as NSError
        if nse.domain == NSURLErrorDomain && nse.code == NSURLErrorTimedOut { return true }
        if let apiError = error as? APIError, case .requestFailed(let underlying) = apiError {
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
    init(role: MessageRole, content: String, isError: Bool = false,
         toolCalls: [ToolCall]? = nil, toolCallID: String? = nil,
         images: [ImageAttachment] = [],
         providerId: String? = nil, modelName: String? = nil,
         latency: Double? = nil, inputTokens: Int? = nil,
         outputTokens: Int? = nil, totalTokens: Int? = nil,
         timeToFirstToken: Double? = nil, streamingDuration: Double? = nil,
         thinkingDuration: Double? = nil, finishReason: String? = nil,
         requestId: String? = nil, temperature: Double? = nil,
         maxTokens: Int? = nil, thinkingContent: String? = nil,
         isTransientStatus: Bool = false) {
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
        self.isTransientStatus = isTransientStatus
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
         maxTokens: Int? = nil, thinkingContent: String? = nil,
         isTransientStatus: Bool = false) {
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
        self.isTransientStatus = isTransientStatus
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
        lhs.latency == rhs.latency &&
        lhs.isTransientStatus == rhs.isTransientStatus
    }
}
