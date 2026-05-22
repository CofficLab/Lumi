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

    public init(
        content: String,
        images: [ImageAttachment] = [],
        isError: Bool = false,
        executedAt: Date = Date()
    ) {
        self.content = content
        self.images = images
        self.isError = isError
        self.executedAt = executedAt
    }
}
