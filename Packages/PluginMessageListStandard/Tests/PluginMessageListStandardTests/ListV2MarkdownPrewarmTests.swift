import Foundation
import ProviderMessage
import Testing
import KitMessageList
@testable import PluginMessageListStandard

/// #1249：会话切换后，上一会话遗留的后台 Markdown 预热批次必须停止，
/// 不再继续解析并向共享缓存写入 obsolete 条目。
///
/// 这些用例走真实 ViewModel + 真实分页服务，仅把预热写入缝隙
/// （`markdownWarm`）替身化，以便确定性地观测/门控后台预热行为。
@MainActor
@Suite("V2 Markdown 预热生命周期")
struct ListV2MarkdownPrewarmTests {

    @Test("切换会话取消遗留预热批次，obsolete 内容不再写入缓存")
    func conversationSwitchCancelsObsoletePrewarmBatch() async {
        let conversationA = UUID()
        let conversationB = UUID()
        let pageA = (0..<10).map {
            makeMessage(conversationID: conversationA, role: .assistant, content: "A\($0)")
        }
        let pageB = (0..<2).map {
            makeMessage(conversationID: conversationB, role: .assistant, content: "B\($0)")
        }
        let capability = SequencedMessageListMessageCapability(pages: [pageA, pageB])
        let harness = ViewModelHarness(selected: conversationA, messages: capability)

        let recorder = PrewarmRecorder()
        harness.viewModel.markdownWarm = { content in
            // 只门控第一条 A 内容：把它停在「已过取消检查、正在写入」的位置，
            // 模拟一个已经开始的 obsolete 批次。后续 A 内容不再阻塞，
            // 这样即使取消检查失效也能干净地断言失败，而不是死锁。
            if content.hasPrefix("A"), recorder.claimFirstA() {
                recorder.markReachedGate()
                recorder.gate.wait()
            }
            recorder.record(content)
        }

        await harness.viewModel.activateCurrentConversation()
        #expect(await waitUntil { recorder.reachedGate }, "A 的预热批次应已开始并停在门闩处")

        // 切到 B：必须取消 A 的遗留批次。
        harness.conversations.selectedConversationID = conversationB
        await harness.viewModel.activateCurrentConversation()

        // 放行被门控的 A0；此后 A 批次应在下一条前检查到取消并退出。
        recorder.gate.signal()
        #expect(await waitUntil { recorder.warmed.contains("A0") })
        #expect(await waitUntil { recorder.warmed.contains("B0") && recorder.warmed.contains("B1") })
        // 给「取消检查失效」的错误实现留出继续写入 A1…A9 的时间窗口。
        try? await Task.sleep(for: .milliseconds(80))

        let warmed = Set(recorder.warmed)
        #expect(warmed.contains("A0"), "门闩放行前已在写入的那一条允许完成")
        for index in 1..<10 {
            #expect(!warmed.contains("A\(index)"), "切换后 obsolete 批次不得继续写入 A\(index)")
        }
        #expect(warmed.contains("B0") && warmed.contains("B1"), "当前会话 B 的内容应正常预热")
    }

    @Test("同一会话内的消息全部正常预热，不误取消")
    func sameConversationWarmsAllMessages() async {
        let conversationID = UUID()
        let page = (0..<5).map {
            makeMessage(conversationID: conversationID, role: .assistant, content: "C\($0)")
        }
        let harness = ViewModelHarness(selected: conversationID, page: page)
        let recorder = PrewarmRecorder()
        harness.viewModel.markdownWarm = { recorder.record($0) }

        await harness.viewModel.activateCurrentConversation()

        #expect(await waitUntil { recorder.warmed.count == 5 })
        #expect(Set(recorder.warmed) == Set((0..<5).map { "C\($0)" }))
    }
}

// MARK: - Helpers

@MainActor
private func waitUntil(
    timeout: Duration = .seconds(2),
    condition: @MainActor () -> Bool
) async -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while clock.now < deadline {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(5))
    }
    return condition()
}

/// 线程安全的预热记录器：后台 detached 任务写入，MainActor 测试读取。
private final class PrewarmRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var _warmed: [String] = []
    private var _reachedGate = false
    private var _claimedFirstA = false
    let gate = DispatchSemaphore(value: 0)

    var warmed: [String] {
        lock.lock(); defer { lock.unlock() }
        return _warmed
    }

    var reachedGate: Bool {
        lock.lock(); defer { lock.unlock() }
        return _reachedGate
    }

    func record(_ content: String) {
        lock.lock(); _warmed.append(content); lock.unlock()
    }

    func markReachedGate() {
        lock.lock(); _reachedGate = true; lock.unlock()
    }

    /// 仅第一条 A 内容返回 true，用于一次性门控。
    func claimFirstA() -> Bool {
        lock.lock(); defer { lock.unlock() }
        if _claimedFirstA { return false }
        _claimedFirstA = true
        return true
    }
}