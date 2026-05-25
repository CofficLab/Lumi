import Foundation

/// 消息发送上下文
///
/// 在消息发送流程中贯穿整个中间件管道，承载本轮发送所需的全部状态和依赖。
///
/// ## 设计目的
/// - 作为中间件之间的数据载体，避免在中间件间传递过多参数
/// - 提供对本轮发送流程的控制能力（如 abort、临时提示词注入）
/// - 集中管理 LLM 请求所需的配置、项目上下文和历史记录服务
///
/// ## 生命周期
/// 每次用户发送消息时创建一个新实例，随本轮发送完成而销毁。
@MainActor
open class SendMessageContext {

    // MARK: - Immutable Properties

    /// 所属会话的唯一标识
    public let conversationId: UUID

    /// 用户本次发送的聊天消息
    public let message: ChatMessage

    /// 当前选中的文件 URL（可选）
    public let currentFileURL: URL?

    // MARK: - Mutable Properties

    /// 仅在当前发送轮次有效的 system 提示词（不落库）
    public var transientSystemPrompts: [String] = []

    /// 终止本轮发送的回调
    public var abortTurn: (() -> Void)?

    // MARK: - Initializer (LumiCoreKit 最小集合)

    /// LumiCoreKit 提供的简化初始化器
    ///
    /// 内核在创建 SendMessageContext 时使用完整初始化器（包含所有服务依赖），
    /// 插件和测试可以使用此简化版本。
    public init(
        conversationId: UUID,
        message: ChatMessage,
        currentFileURL: URL? = nil
    ) {
        self.conversationId = conversationId
        self.message = message
        self.currentFileURL = currentFileURL
    }

    // MARK: - Public Methods

    /// 终止当前发送
    public func abort() {
        abortTurn?()
    }
}
