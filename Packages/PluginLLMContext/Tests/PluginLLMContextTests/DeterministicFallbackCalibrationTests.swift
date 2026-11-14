import Foundation
import KitLLM
import ProviderConversation
import ProviderLLMContext
import ProviderLLMManager
import ProviderMessage
import Testing

@testable import PluginLLMContext

/// 确定性降级必须用校准倍率折算可用预算（回归 #813）。
///
/// `reportContextLimitExceeded` 把校准倍率学到 ≥1.25 后，同一份历史的真实
/// token 被放大。若降级仍按未校准的 `inputTokenLimit` 挑选，估算落在
/// `limit/factor … limit` 区间的历史会被原样选中，紧急重试把已确认超限的
/// 请求再发一次。降级必须把预算折算回未校准量纲（limit / factor）再裁剪。
@MainActor
struct DeterministicFallbackCalibrationTests {
    /// 约 1,096 token 输入上限：触发确定性降级且不依赖摘要 Provider。
    private static func request(conversationID: UUID) -> LLMContextPreparationRequest {
        LLMContextPreparationRequest(
            conversationID: conversationID,
            providerID: nil,
            model: nil,
            budget: LLMContextBudget(
                contextWindowTokens: 4_096,
                reservedOutputTokens: 2_000,
                safetyMarginTokens: 1_000
            ),
            mode: .beforeSend
        )
    }

    @Test("超限学习校准倍率后，紧急降级必须按折算预算真正裁剪历史（#813）")
    func emergencyFallbackTrimsWithCalibratedBudget() async {
        let messages = DefaultMessageManager()
        let provider = LLMContextProvider(
            messages: messages,
            conversations: DefaultConversationManager(),
            llmProvider: DefaultLLMManager()
        )
        let conversationID = UUID()
        let base = Date(timeIntervalSince1970: 1_000_000)

        // 4 条用户消息，未校准估算约 848 token：落在 limit(1096) 之内，
        // 但校准后（×1.5625 ≈ 1325）超限。消息数低于折叠阈值，不会生成摘要块，
        // 因此 prepareContext 必然走到确定性降级。
        for index in 0..<4 {
            messages.insertMessage(
                Message(
                    conversationID: conversationID,
                    role: .user,
                    content: String(repeating: "a", count: 600),
                    createdAt: base.addingTimeInterval(Double(index))
                ),
                to: conversationID
            )
        }

        let request = Self.request(conversationID: conversationID)
        // 模拟 provider 返回上下文超限：学习倍率并标记强制压缩。
        provider.reportContextLimitExceeded(for: request)

        let result = await provider.prepareContext(for: request)

        #expect(result.didFallback)
        // 核心不变量：紧急重试发出的内容，其校准估算不得超过输入上限。
        #expect(result.estimatedInputTokens <= result.inputTokenLimit)
        // 必须真正裁剪，而不是把整段超限历史原样再发一次。
        #expect(result.messages.count < 4)
        #expect(result.messages.contains { $0.role == .user })
    }
}