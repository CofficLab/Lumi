import Foundation

/// 单次工具调用的执行结果（与调用请求存放在同一 `ToolCall` 中）。
public struct ToolCallResult: Codable, Sendable, Equatable {
    /// 返回给 LLM 的文本内容
    public var content: String

    /// 结果中的图片附件
    public var images: [ImageAttachment]

    /// 是否为错误结果
    public var isError: Bool

    /// 执行完成时间
    public var executedAt: Date

    /// 执行耗时（秒），精确记录从工具开始执行到完成的时间间隔
    public var duration: TimeInterval?

    /// 工具正在等待用户回答，Agent 循环应暂停。
    ///
    /// 当工具（如 `ask_user`）需要用户在 UI 上做出选择时，
    /// `execute()` 返回 `__ASK_USER_PENDING__` 前缀字符串，
    /// `ToolCallExecutor` 据此设置此标记为 `true`。
    /// `AgentTurnService` 检测到后暂停循环，直到用户操作后恢复。
    public var awaitingUserResponse: Bool

    public init(
        content: String,
        images: [ImageAttachment] = [],
        isError: Bool = false,
        executedAt: Date = Date(),
        duration: TimeInterval? = nil,
        awaitingUserResponse: Bool = false
    ) {
        self.content = content
        self.images = images
        self.isError = isError
        self.executedAt = executedAt
        self.duration = duration
        self.awaitingUserResponse = awaitingUserResponse
    }

    // MARK: - Codable（兼容旧数据）

    private enum CodingKeys: String, CodingKey {
        case content, images, isError, executedAt, duration, awaitingUserResponse
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        content = try c.decode(String.self, forKey: .content)
        images = try c.decodeIfPresent([ImageAttachment].self, forKey: .images) ?? []
        isError = try c.decodeIfPresent(Bool.self, forKey: .isError) ?? false
        executedAt = try c.decodeIfPresent(Date.self, forKey: .executedAt) ?? Date()
        duration = try c.decodeIfPresent(TimeInterval.self, forKey: .duration)
        awaitingUserResponse = try c.decodeIfPresent(Bool.self, forKey: .awaitingUserResponse) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(content, forKey: .content)
        if !images.isEmpty { try c.encode(images, forKey: .images) }
        if isError { try c.encode(isError, forKey: .isError) }
        try c.encode(executedAt, forKey: .executedAt)
        if let duration { try c.encode(duration, forKey: .duration) }
        if awaitingUserResponse { try c.encode(awaitingUserResponse, forKey: .awaitingUserResponse) }
    }
}
