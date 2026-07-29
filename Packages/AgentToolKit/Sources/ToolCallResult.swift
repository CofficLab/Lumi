import Foundation

public enum ToolCallInteractionState: Codable, Sendable, Equatable {
    case waiting
    case answered(String)

    public var answer: String? {
        guard case let .answered(answer) = self else { return nil }
        return answer
    }
}

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
    /// 由 LumiKernel 的结构化 `AgentTurnControl.suspend` 转换而来。
    public var awaitingUserResponse: Bool

    /// Preserves a custom interaction renderer after the interaction is answered.
    public var interactionState: ToolCallInteractionState?

    public init(
        content: String,
        images: [ImageAttachment] = [],
        isError: Bool = false,
        executedAt: Date = Date(),
        duration: TimeInterval? = nil,
        awaitingUserResponse: Bool = false,
        interactionState: ToolCallInteractionState? = nil
    ) {
        self.content = content
        self.images = images
        self.isError = isError
        self.executedAt = executedAt
        self.duration = duration
        self.awaitingUserResponse = awaitingUserResponse
        self.interactionState = interactionState
    }

    // MARK: - Codable（兼容旧数据）

    private enum CodingKeys: String, CodingKey {
        case content, images, isError, executedAt, duration, awaitingUserResponse, interactionState
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        content = try c.decode(String.self, forKey: .content)
        images = try c.decodeIfPresent([ImageAttachment].self, forKey: .images) ?? []
        isError = try c.decodeIfPresent(Bool.self, forKey: .isError) ?? false
        executedAt = try c.decodeIfPresent(Date.self, forKey: .executedAt) ?? Date()
        duration = try c.decodeIfPresent(TimeInterval.self, forKey: .duration)
        awaitingUserResponse = try c.decodeIfPresent(Bool.self, forKey: .awaitingUserResponse) ?? false
        interactionState = try c.decodeIfPresent(ToolCallInteractionState.self, forKey: .interactionState)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(content, forKey: .content)
        if !images.isEmpty { try c.encode(images, forKey: .images) }
        if isError { try c.encode(isError, forKey: .isError) }
        try c.encode(executedAt, forKey: .executedAt)
        if let duration { try c.encode(duration, forKey: .duration) }
        if awaitingUserResponse { try c.encode(awaitingUserResponse, forKey: .awaitingUserResponse) }
        if let interactionState { try c.encode(interactionState, forKey: .interactionState) }
    }
}
