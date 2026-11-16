import AppKit
import CoreGraphics
import Foundation
import ProviderMessage
import Testing
@testable import PluginMessageListChatGPT

/// 无窗口环境下构造真实 NSScrollView + NSClipView + 文档视图（同 ScrollViewHost 模式）。
@MainActor
private final class PrependScrollViewHost {
    let scrollView = NSScrollView()
    let documentView = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 1_000))
    let container = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 600))

    init() {
        scrollView.documentView = documentView
        scrollView.hasVerticalScroller = true
        scrollView.frame = NSRect(x: 0, y: 0, width: 400, height: 600)
        scrollView.contentView.frame = NSRect(x: 0, y: 0, width: 400, height: 600)
        container.addSubview(scrollView)
        scrollView.contentView.postsBoundsChangedNotifications = true
    }

    func setDocumentHeight(_ height: CGFloat) {
        documentView.frame = NSRect(x: 0, y: 0, width: 400, height: height)
        if scrollView.contentView.bounds.height == 0 {
            scrollView.contentView.frame = NSRect(x: 0, y: 0, width: 400, height: 600)
        }
    }
}

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
    let host = PrependScrollViewHost()
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
    let host = PrependScrollViewHost()
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
    let host = PrependScrollViewHost()
    let controller = ScrollViewBottomController()
    let tracker = TrackerView()
    tracker.setBottomController(controller)
    tracker.attachForTesting(to: host.scrollView)

    controller.isRestoringAnchor = true
    // 会话切换重建 List → tracker 重新绑定新的滚动视图。
    let newHost = PrependScrollViewHost()
    tracker.attachForTesting(to: newHost.scrollView)

    #expect(!controller.isRestoringAnchor)
}

/// 记录滚动调用序列的测试替身（#1330 专用，避免与既有夹具重名）。
@MainActor
private final class PrependStubTarget: MessageListScrollingTarget {
    enum Call: Equatable {
        case scrollToBottom(animated: Bool)
        case scrollToAnchorTop(UUID)
    }

    private(set) var calls: [Call] = []
    var isAttached = false
    private(set) var anchorRestoringFlags: [Bool] = []
    var documentHeights: [CGFloat?] = []

    var bottomScrollCount: Int {
        calls.filter { if case .scrollToBottom = $0 { return true } else { return false } }.count
    }

    func pinToBottom() -> ScrollViewBottomController.Snapshot? { nil }
    func scrollToBottom(animated: Bool) { calls.append(.scrollToBottom(animated: animated)) }
    func scrollToAnchorTop(_ anchorID: UUID) { calls.append(.scrollToAnchorTop(anchorID)) }
    func setAnchorRestoring(_ active: Bool) { anchorRestoringFlags.append(active) }
    func documentHeight() -> CGFloat? {
        guard !documentHeights.isEmpty else { return nil }
        return documentHeights.removeFirst()
    }
}

@MainActor
@Test("锚点恢复会取消已排程的底部跟随，并全程持有恢复标记")
func pinToAnchorCancelsScheduledBottomFollow() async {
    let coordinator = MessageListScrollCoordinator()
    let target = PrependStubTarget()
    let anchorID = UUID()

    coordinator.scheduleScrollToBottomAfterLayout(
        target: target,
        messages: [Message(conversationID: UUID(), role: .user, content: "x")],
        animated: false
    )
    await coordinator.pinToAnchor(target: target, anchorID: anchorID)

    try? await Task.sleep(
        nanoseconds: MessageListScrollCoordinator.postAppendDelayNs
            + MessageListScrollCoordinator.scrollRetryDelayNs + 80_000_000
    )

    #expect(target.bottomScrollCount == 0)
    #expect(target.calls == [.scrollToAnchorTop(anchorID)])
    #expect(target.anchorRestoringFlags == [true, false])
}

@MainActor
@Test("锚点恢复在文档高度稳定前持续重试钉回锚点")
func pinToAnchorRetriesUntilDocumentStable() async {
    let coordinator = MessageListScrollCoordinator()
    let target = PrependStubTarget()
    let anchorID = UUID()
    target.documentHeights = [1000, 1400, 1800, 1800, 1800, 1800]

    await coordinator.pinToAnchor(target: target, anchorID: anchorID)

    #expect(target.calls == Array(repeating: .scrollToAnchorTop(anchorID), count: 6))
    #expect(target.anchorRestoringFlags == [true, false])
}
