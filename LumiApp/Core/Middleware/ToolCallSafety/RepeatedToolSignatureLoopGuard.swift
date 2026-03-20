import Foundation
import MagicKit

/// 重复工具签名循环保护（同名 + 同参数）：
/// - 连续重复达到 `repeatedToolSignatureThreshold` 次视为循环
/// - 或者在最近窗口中同一签名出现达到 `repeatedToolWindowThreshold` 次视为循环
///
/// 该守卫用于替代 `ConversationTurnVM` 内部硬编码逻辑，使其更接近“中间件/策略”的组织方式。
struct RepeatedToolSignatureLoopGuard {
    struct Config {
        let repeatedToolSignatureThreshold: Int
        let repeatedToolWindowThreshold: Int
        let recentWindowMaxCount: Int
        let signatureArgsPrefixLength: Int
    }

    enum Result {
        case proceed
        case abort(message: ChatMessage, error: NSError)
    }

    func evaluate(
        firstTool: ToolCall,
        toolCalls: [ToolCall],
        languagePreference: LanguagePreference,
        context: inout ConversationTurnContext,
        config: Config
    ) -> Result {
        let normalizedArgs = firstTool.arguments
            .replacingOccurrences(
                of: "\\s+",
                with: "",
                options: .regularExpression
            )
        let signaturePrefix = String(normalizedArgs.prefix(config.signatureArgsPrefixLength))
        let signature = "\(firstTool.name)|\(signaturePrefix)"

        if context.lastToolSignature == signature {
            context.repeatedToolSignatureCount += 1
        } else {
            context.lastToolSignature = signature
            context.repeatedToolSignatureCount = 1
        }

        context.recentToolSignatures.append(signature)
        if context.recentToolSignatures.count > config.recentWindowMaxCount {
            context.recentToolSignatures.removeFirst(context.recentToolSignatures.count - config.recentWindowMaxCount)
        }

        let sameSignatureInWindow = context.recentToolSignatures.filter { $0 == signature }.count

        guard context.repeatedToolSignatureCount >= config.repeatedToolSignatureThreshold ||
                sameSignatureInWindow >= config.repeatedToolWindowThreshold
        else {
            return .proceed
        }

        let explainMessage = ChatMessage.repeatedToolLoopMessage(
            languagePreference: languagePreference,
            tool: firstTool,
            repeatedCount: context.repeatedToolSignatureCount,
            windowCount: sameSignatureInWindow
        )

        // 复刻原有错误码语义：410 - 重复工具调用循环中止
        let error = NSError(
            domain: "ConversationTurn",
            code: 410,
            userInfo: [NSLocalizedDescriptionKey: "检测到重复工具调用循环，已自动中止本轮。"]
        )

        // abort 时清空 pending tool calls（VM 原逻辑会 removeAll）。
        context.pendingToolCalls.removeAll()

        // `toolCalls` 当前仅用于生成 abort tool 输出；实际 `.toolResultReceived` 由上层 VM 产出。
        _ = toolCalls

        return .abort(message: explainMessage, error: error)
    }
}

