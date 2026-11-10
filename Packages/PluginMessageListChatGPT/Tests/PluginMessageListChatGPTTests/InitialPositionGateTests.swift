import Foundation
import Testing
@testable import PluginMessageListChatGPT

/// V5（ChatGPT）首屏定位 gate 测试。
///
/// 基准是 V5 方案 Task 6 的要求：
/// - 首屏 gate 超时能解除 mask；
/// - 失效 generation 不写回。
@MainActor
@Suite("V5 首屏定位 gate")
struct InitialPositionGateTests {

    @Test("没有选中会话时直接就绪")
    func readyWithoutConversation() {
        let gate = InitialPositionGate()

        let started = gate.request(
            conversationID: nil,
            settle: { false },
            stillRelevant: { true }
        )

        #expect(started)
        #expect(gate.isReady)
        #expect(!gate.isPreparing)
    }

    @Test("收敛成功后放行遮罩")
    func readyAfterSuccessfulSettle() async {
        let gate = InitialPositionGate(budgetNanoseconds: 5_000_000_000)
        let conversationID = UUID()

        gate.request(
            conversationID: conversationID,
            settle: { true },
            stillRelevant: { true }
        )

        // 等待收敛轮次落地。
        for _ in 0..<50 {
            if gate.isReady { break }
            await Task.yield()
        }

        #expect(gate.isReady)
        #expect(!gate.isPreparing)
    }

    @Test("收敛挂死时超时兜底放行遮罩")
    func deadlineReleasesMaskWhenSettleHangs() async {
        // 预算很短，模拟「收敛永远不返回」。
        let gate = InitialPositionGate(budgetNanoseconds: 20_000_000)
        let conversationID = UUID()

        gate.request(
            conversationID: conversationID,
            settle: {
                // 永不返回。
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    _ = continuation
                }
                return false
            },
            stillRelevant: { true }
        )

        #expect(!gate.isReady)

        // 等待兜底计时器到点。
        try? await Task.sleep(nanoseconds: 120_000_000)

        #expect(gate.isReady)
        #expect(!gate.isPreparing)
    }

    @Test("失效的一轮释放准备状态，不焊死门禁")
    func invalidatedRoundReleasesPreparingState() async {
        let gate = InitialPositionGate(budgetNanoseconds: 5_000_000_000)
        let conversationID = UUID()

        gate.request(
            conversationID: conversationID,
            settle: { true },
            stillRelevant: { false }
        )

        for _ in 0..<50 {
            if !gate.isPreparing && !gate.isReady { break }
            await Task.yield()
        }

        // 失效的一轮既不置为就绪，也必须释放准备状态。
        #expect(!gate.isReady)
        #expect(!gate.isPreparing)
    }

    @Test("同会话的并发请求被去重")
    func duplicateRequestsAreDeduplicated() async {
        let gate = InitialPositionGate(budgetNanoseconds: 5_000_000_000)
        let conversationID = UUID()

        let first = gate.request(
            conversationID: conversationID,
            settle: { true },
            stillRelevant: { true }
        )
        let second = gate.request(
            conversationID: conversationID,
            settle: { true },
            stillRelevant: { true }
        )

        #expect(first)
        #expect(!second)
    }

    @Test("会话切换复位后遮罩重新挂起")
    func conversationSwitchResetsGate() async {
        let gate = InitialPositionGate(budgetNanoseconds: 5_000_000_000)
        let conversationID = UUID()

        gate.request(
            conversationID: conversationID,
            settle: { true },
            stillRelevant: { true }
        )
        for _ in 0..<50 {
            if gate.isReady { break }
            await Task.yield()
        }
        #expect(gate.isReady)

        gate.resetForConversationSwitch()

        #expect(!gate.isReady)
    }

    @Test("加载开始复位后遮罩重新挂起")
    func loadingStartResetsGate() async {
        let gate = InitialPositionGate(budgetNanoseconds: 5_000_000_000)
        let conversationID = UUID()

        gate.request(
            conversationID: conversationID,
            settle: { true },
            stillRelevant: { true }
        )
        for _ in 0..<50 {
            if gate.isReady { break }
            await Task.yield()
        }

        gate.resetForLoadingStart()

        #expect(!gate.isReady)
        #expect(!gate.isPreparing)
    }
}
