import AppKit
import CoreGraphics
import Foundation
import KitMessageList
import Testing
@testable import PluginMessageListDetailed

/// 「加载更早消息后视口跳到底部」的回归测试（#1330）。
///
/// issue 里的确定性复现：已加载窗口恰好填满视口（或距底部不超过 96pt）时，
/// `atBottom` 判定为 true；此时 prepend 让文档长高，tracker 把这次增长当成
/// 「新消息到达」，直接把 clip view 钉到新的底部 —— 用户刚点击的行被甩出屏幕。
///
/// 修复后：锚点恢复期间（`isRestoringAnchor`）tracker 只更新簿记、不钉底。

@MainActor
private func waitUntil(
    timeout: TimeInterval = 2.0,
    _ condition: () -> Bool
) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return condition()
}

@MainActor
@Test("锚点恢复期间：prepend 式文档增长不得把视口钉到新底部")
func growthDuringAnchorRestoreDoesNotPinToBottom() async {
    let host = ScrollViewHost()
    // 文档 400 < 视口 600：窗口填满视口，offset 只能是 0，atBottom == true。
    host.setDocumentHeight(400)
    let controller = ScrollViewBottomController()
    let tracker = TrackerView()
    tracker.setBottomController(controller)
    tracker.attachForTesting(to: host.scrollView)

    _ = controller.pinToBottom()
    #expect(host.scrollView.contentView.bounds.origin.y == 0)
    #expect(tracker.lastReportedAtBottomForTesting)

    // 进入锚点恢复（pinToAnchor 的入口动作），随后 prepend 让文档长高。
    controller.isRestoringAnchor = true
    host.setDocumentHeight(2_800)

    // 负面断言：等满一个窗口，确认钉底没有发生。
    let didPin = await waitUntil(timeout: 0.3) {
        host.scrollView.contentView.bounds.origin.y > 48
    }
    let offset = host.scrollView.contentView.bounds.origin.y
    #expect(!didPin, "锚点恢复期间被钉到了新底部（offset=\(offset)，期望保持 0 附近）")
    _ = tracker.lastReportedAtBottomForTesting
}

@MainActor
@Test("锚点恢复结束后：簿记已更新，后续增长不得用陈旧几何误判钉底")
func growthAfterAnchorRestoreUsesFreshBookkeeping() async {
    let host = ScrollViewHost()
    host.setDocumentHeight(400)
    let controller = ScrollViewBottomController()
    let tracker = TrackerView()
    tracker.setBottomController(controller)
    tracker.attachForTesting(to: host.scrollView)

    _ = controller.pinToBottom()
    controller.isRestoringAnchor = true
    host.setDocumentHeight(2_800)
    // 等 tracker 处理完这次（被抑制的）增长。
    _ = await waitUntil(timeout: 0.3) { false }

    // 恢复结束：用户停在旧首行（offset 0），距新底部 2200pt，远超 96pt 容差。
    controller.isRestoringAnchor = false
    host.setDocumentHeight(3_000)
    let didPin = await waitUntil(timeout: 0.3) {
        host.scrollView.contentView.bounds.origin.y > 48
    }
    let offset = host.scrollView.contentView.bounds.origin.y
    #expect(!didPin, "恢复结束后被陈旧簿记误判钉底（offset=\(offset)，期望保持 0）")
    _ = tracker.lastReportedAtBottomForTesting
}

@MainActor
@Test("绑定新的滚动视图时：锚点恢复标记必须被重置")
func attachResetsAnchorRestoreFlag() async {
    let host = ScrollViewHost()
    let controller = ScrollViewBottomController()
    let tracker = TrackerView()
    tracker.setBottomController(controller)
    tracker.attachForTesting(to: host.scrollView)

    controller.isRestoringAnchor = true
    // 会话切换重建 List → tracker 重新绑定新的滚动视图。
    let newHost = ScrollViewHost()
    tracker.attachForTesting(to: newHost.scrollView)

    #expect(!controller.isRestoringAnchor)
}

/// 历史窗口变化分类（#1330）：prepend 只改头部，不是「新内容到达」。
@Suite("历史窗口变化分类")
struct HistoryWindowChangeTests {
    @Test("prepend（只有头部变化）不算新尾部内容")
    func prependIsNotNewTail() {
        let last = UUID()
        let none: UUID? = nil
        #expect(!HistoryWindowChange.hasNewTail(oldLast: last, newLast: last))
        #expect(!HistoryWindowChange.hasNewTail(oldLast: none, newLast: none))
    }

    @Test("append / 首屏加载 / 会话切换都算新尾部内容")
    func tailGrowthIsNewTail() {
        let old = UUID(), new = UUID()
        #expect(HistoryWindowChange.hasNewTail(oldLast: old, newLast: new))
        #expect(HistoryWindowChange.hasNewTail(oldLast: nil, newLast: new))
    }
}