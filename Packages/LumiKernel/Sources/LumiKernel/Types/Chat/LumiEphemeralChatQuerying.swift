import Foundation

/// "通过 chat 服务获得一个不写入历史的消息补全"的最小接口。
///
/// 该协议是从 `LumiChatServicing` 中剥离出来的子集 —— 仅保留
/// `GitPlugin` 等"想在 chat 体系内做一次性调用"的消费者真正需要的
/// 4 个成员。这样这些消费者就不必再依赖巨大的 `LumiChatServicing`。
///
/// 现状:
/// - `LumiChatServicing` **不再继承** `LumiEphemeralChatQuerying`,
///   两者并列,由具体 chat service 类型按需声明自己满足该子集。
/// - `LumiCore` 在初始化时通过 `as?` 下转,显式以本协议类型把服务注册进来。
/// - 消费者(如 GitPlugin)通过 `kernel.resolveService((any LumiEphemeralChatQuerying).self)`
///   或注入式桥接(如 `GitRuntimeBridge`)拿到该服务。
@MainActor
public protocol LumiEphemeralChatQuerying: AnyObject {
    /// 当前选中的对话 id。若没有则调用方可自行决定使用新 UUID 还是直接报缺对话错。
    var selectedConversationID: UUID? { get }

    /// 当前选中的模型 id。
    var selectedModel: String? { get }

    /// 获取指定对话当前生效的模型名。某些场景下 `selectedModel` 仅是 fallback。
    func modelName(for conversationID: UUID?) -> String?

    /// 生成一个**不写入任何对话历史**的临时补全。
    /// - Parameters:
    ///   - messages: 调用方提供的消息上下文。
    ///   - model: 要使用的模型名。
    ///   - conversationID: 调用方想要绑定的对话上下文(用于路由/权限等)。
    /// - Returns: LLM 生成的回复消息。
    func generateEphemeralCompletion(
        messages: [LumiChatMessage],
        model: String,
        conversationID: UUID
    ) async throws -> LumiChatMessage
}
