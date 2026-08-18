import Foundation
import Testing
@testable import ProviderLifecycleHooks
import KitLLM

@Suite("DefaultLifecycleHooksProvider")
struct DefaultLifecycleHooksProviderTests {
    @MainActor
    @Test("willSendToLLM 串行执行钩子链")
    func testWillSendToLLMChain() async {
        let provider = DefaultLifecycleHooksProvider()

        // 钩子 1：在消息前面加一个 tag
        provider.addWillSendToLLMHook { context in
            var ctx = context
            var msg = ctx.messages.first ?? LLMMessage(role: .system, content: "")
            msg.content = "[hook1]" + msg.content
            ctx.messages = [msg]
            return ctx
        }

        // 钩子 2：追加一个新消息
        provider.addWillSendToLLMHook { context in
            var ctx = context
            ctx.messages.append(LLMMessage(role: .system, content: "[hook2]"))
            return ctx
        }

        let initial = WillSendToLLMContext(
            messages: [LLMMessage(role: .system, content: "hello")],
            conversationID: UUID()
        )

        let result = await provider.runWillSendToLLM(initial)
        #expect(result.messages.count == 2)
        #expect(result.messages[0].content == "[hook1]hello")
        #expect(result.messages[1].content == "[hook2]")
    }

    @MainActor
    @Test("notifyTurnFinished 触发所有注册钩子")
    func testNotifyTurnFinished() async {
        let provider = DefaultLifecycleHooksProvider()
        var callCount = 0

        provider.addTurnFinishedHook { _ in callCount += 1 }
        provider.addTurnFinishedHook { _ in callCount += 1 }

        let ctx = TurnLifecycleContext(
            conversationID: UUID(),
            turnID: UUID(),
            endReason: .completed
        )
        await provider.notifyTurnFinished(ctx)
        #expect(callCount == 2)
    }

    @MainActor
    @Test("无钩子时 runWillSendToLLM 原样返回")
    func testEmptyHooksPassthrough() async {
        let provider = DefaultLifecycleHooksProvider()
        let ctx = WillSendToLLMContext(
            messages: [LLMMessage(role: .user, content: "test")],
            conversationID: UUID()
        )
        let result = await provider.runWillSendToLLM(ctx)
        #expect(result.messages == ctx.messages)
    }
}
