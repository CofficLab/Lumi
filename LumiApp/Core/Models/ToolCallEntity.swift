import Foundation
import AgentToolKit
import SwiftData

/// 工具调用实体
///
/// 独立存储 AI 助手发起的每次工具调用及其执行结果。
/// 通过多对一关系关联到 ChatMessageEntity（assistant 消息）。
///
/// ## 关系说明
///
/// ```text
/// ChatMessageEntity (assistant)
///   └── toolCalls → [ToolCallEntity]   (调用请求 + 执行结果)
/// ```
@Model
final class ToolCallEntity {
    /// 工具调用唯一标识符（对应 LLM 返回的 call_id）
    @Attribute(.unique) var id: String

    /// 工具名称（如 "read_file"、"run_command"）
    var name: String

    /// 工具参数（JSON 字符串）
    var arguments: String

    /// 授权状态（本地 UI 用）
    var authorizationState: String

    /// 执行结果文本
    var resultContent: String?

    /// 结果是否为错误
    var resultIsError: Bool

    /// 结果执行完成时间
    var resultExecutedAt: Date?

    /// 结果中的图片附件
    @Relationship(deleteRule: .nullify, inverse: \ImageAttachmentEntity.toolCallResults)
    var resultImages: [ImageAttachmentEntity] = []

    /// 创建时间
    var createdAt: Date

    /// 所属消息（多对一：多条 toolCall 属于同一条 assistant 消息）
    var message: ChatMessageEntity?

    init(
        id: String,
        name: String,
        arguments: String,
        authorizationState: ToolCallAuthorizationState = .pendingAuthorization,
        result: ToolCallResult? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.arguments = arguments
        self.authorizationState = authorizationState.rawValue
        self.resultContent = result?.content
        self.resultIsError = result?.isError ?? false
        self.resultExecutedAt = result?.executedAt
        self.createdAt = createdAt
    }

    // MARK: - 业务模型转换

    /// 转换为业务层 ToolCall 模型
    func toToolCall() -> ToolCall {
        var result: ToolCallResult?
        if let resultContent {
            result = ToolCallResult(
                content: resultContent,
                images: resultImages.map { $0.toImageAttachment() },
                isError: resultIsError,
                executedAt: resultExecutedAt ?? createdAt
            )
        }

        return ToolCall(
            id: id,
            name: name,
            arguments: arguments,
            authorizationState: ToolCallAuthorizationState(rawValue: authorizationState)
                ?? .pendingAuthorization,
            result: result
        )
    }

    /// 从业务层 ToolCall 模型创建实体
    static func from(_ toolCall: ToolCall) -> ToolCallEntity {
        ToolCallEntity(
            id: toolCall.id,
            name: toolCall.name,
            arguments: toolCall.arguments,
            authorizationState: toolCall.authorizationState,
            result: toolCall.result
        )
    }

    /// 更新实体字段（不含图片关系，由 ChatHistoryService 同步）
    func apply(from toolCall: ToolCall) {
        name = toolCall.name
        arguments = toolCall.arguments
        authorizationState = toolCall.authorizationState.rawValue
        resultContent = toolCall.result?.content
        resultIsError = toolCall.result?.isError ?? false
        resultExecutedAt = toolCall.result?.executedAt
    }
}
