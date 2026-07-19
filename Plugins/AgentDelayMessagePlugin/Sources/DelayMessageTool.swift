import Foundation
import LumiKernel
import SuperLogKit

/// 延时消息工具
///
/// 在指定秒数后向目标会话注入一条用户消息，触发新一轮对话。
/// 等价于用户在延时结束后自己在输入框里敲了一句话。
///
/// ## 工作原理
///
/// 1. LLM 调用 `delay_message(message, seconds)`
/// 3. 工具立即返回，当前回合正常结束
/// 4. 后台 Task sleep N 秒后，通过 `DelayMessageState` 持有的 messageQueueVM 引用入队消息
/// 5. RootView 检测到 queueVersion 变化，触发 attemptBeginNextQueuedSend()
/// 6. 新回合开始，LLM 收到这条用户消息并继续处理
///
/// ## 依赖
///
/// - `DelayMessageState`：@MainActor 单例，存储从 Environment 同步来的 VM 引用
/// - `WindowMessageQueueVM`：消息入队，触发已有的发送闭环
/// - 不依赖 `RootViewContainer.shared`
public struct DelayMessageTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "⏳"
    public nonisolated static let verbose: Bool = true
    static let defaultDelaySeconds: TimeInterval = 5
    static let minDelaySeconds: TimeInterval = 1
    static let maxDelaySeconds: TimeInterval = 3600

    public static let info = LumiAgentToolInfo(
        id: "delay_message",
        displayName: "Delay Message",
        description: "Send a delayed user message to the current conversation after a specified number of seconds. The current turn will end, and a new turn will start when the message arrives."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "message": .object([
                    "type": .string("string"),
                    "description": .string("The message content to send after the delay. This will appear as a user message in the conversation."),
                ]),
                "seconds": .object([
                    "type": .string("number"),
                    "description": .string("Number of seconds to wait before sending the message. Minimum 1, maximum 3600 (1 hour)."),
                    "minimum": .double(Self.minDelaySeconds),
                    "maximum": .double(Self.maxDelaySeconds),
                ]),
            ]),
            "required": .array([.string("message"), .string("seconds")]),
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "延迟发送消息"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        try context.checkCancellation()
        let conversationId = context.conversationID

        // 解析 message
        let message = (arguments.string("message") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else {
            return "Error: message cannot be empty."
        }

        // 解析 seconds
        let seconds = Self.normalizedDelaySeconds(arguments["seconds"]?.anyValue)

        if Self.verbose {
            DelayMessagePlugin.logger.info("\(Self.t) 延时 \(Int(seconds))s 后发送消息到会话 \(conversationId.uuidString.prefix(8))")
        }

        // 启动后台延时任务
        Task { [seconds, message, conversationId] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }

            if Self.verbose {
                DelayMessagePlugin.logger.info("\(Self.t)⏰ 延时到达，注入消息：\(message.prefix(50))")
            }

            // 通过 DelayMessageState 持有的 VM 引用入队，在 MainActor 上执行
            await MainActor.run {
                DelayMessageState.shared.enqueueDelayedMessage(
                    conversationId: conversationId,
                    content: message
                )
            }
        }

        return "Scheduled: a message will be sent in \(Int(seconds)) seconds to conversation \(conversationId.uuidString.prefix(8)). The current turn will end now. When the message arrives, a new turn will start automatically."
    }

    static func normalizedDelaySeconds(_ value: Any?) -> TimeInterval {
        let raw: TimeInterval
        if let double = value as? Double {
            raw = double
        } else if let int = value as? Int {
            raw = TimeInterval(int)
        } else if let string = value as? String, let double = TimeInterval(string) {
            raw = double
        } else {
            raw = Self.defaultDelaySeconds
        }

        guard raw.isFinite else { return Self.defaultDelaySeconds }
        return min(max(raw, Self.minDelaySeconds), Self.maxDelaySeconds)
    }
}
