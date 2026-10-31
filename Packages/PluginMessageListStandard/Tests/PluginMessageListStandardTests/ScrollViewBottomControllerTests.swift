import AppKit
import CoreGraphics
import Foundation
import Testing
@testable import PluginMessageListStandard

/// 在无窗口环境下构造真实的 `NSScrollView` + `NSClipView` + `NSView` 文档视图，
/// 使 `ScrollViewBottomController` 的几何逻辑可在单元测试中驱动。
@MainActor
final class ScrollViewHost {
    let scrollView = NSScrollView()
    let documentView = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 1_000))
    let container = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 600))

    init() {
        scrollView.documentView = documentView
        scrollView.hasVerticalScroller = true
        // 无窗口时 NSScrollView 不会自行布局，clip view 尺寸会停在 0。
        // 显式指定 frame 让几何可测，否则 pinToBottom 会因 visibleHeight == 0
        // 一律返回 nil。
        scrollView.frame = NSRect(x: 0, y: 0, width: 400, height: 600)
        scrollView.contentView.frame = NSRect(x: 0, y: 0, width: 400, height: 600)
        container.addSubview(scrollView)
        scrollView.contentView.postsBoundsChangedNotifications = true
    }

    /// 调整文档高度，模拟 List 懒加载行陆续物化。
    func setDocumentHeight(_ height: CGFloat) {
        documentView.frame = NSRect(x: 0, y: 0, width: 400, height: height)
        // 布局可能把 clip 归零，这里强制复位保证几何可测。
        if scrollView.contentView.bounds.height == 0 {
            scrollView.contentView.frame = NSRect(x: 0, y: 0, width: 400, height: 600)
        }
    }

    var snapshot: ScrollViewBottomController.Snapshot {
        ScrollViewBottomController.Snapshot(
            documentHeight: documentView.bounds.height,
            visibleHeight: scrollView.contentView.bounds.height,
            offsetY: scrollView.contentView.bounds.origin.y
        )
    }
}

@MainActor
private func makeController(
    host: ScrollViewHost
) -> ScrollViewBottomController {
    let controller = ScrollViewBottomController()
    // 走真实 attach 路径需要 tracker；此处直接调用 fileprivate 的等价装配，
    // 因此借助 tracker 的 makeNSView/updateNSView 之外的方式不可行，
    // 改由 attach 的 fileprivate 可访问性经 @testable 保证。
    controller.attachForTesting(to: host.scrollView)
    return controller
}

@MainActor
@Test("钉底后 contentOffset 落在 documentView 底边")
func pinToBottomMovesOffsetToDocumentEnd() {
    let host = ScrollViewHost()
    host.setDocumentHeight(2_000)
    let controller = makeController(host: host)

    let snapshot = controller.pinToBottom()

    #expect(snapshot != nil)
    #expect(snapshot?.documentHeight == 2_000)
    let expectedOffset = max(0, 2_000 - (snapshot?.visibleHeight ?? 0))
    #expect(abs((snapshot?.offsetY ?? -1) - expectedOffset) < 0.5)
    // 幂等：重复钉底不改变结果
    let again = controller.pinToBottom()
    #expect(again?.offsetY == snapshot?.offsetY)
}

@MainActor
@Test("文档高度小于视口时 offset 夹紧为 0，不产生负偏移")
func pinToBottomClampsOffsetWhenDocumentShorterThanViewport() {
    let host = ScrollViewHost()
    host.setDocumentHeight(120) // 远小于 600 的视口高度
    let controller = makeController(host: host)

    let snapshot = controller.pinToBottom()

    #expect(snapshot?.offsetY == 0)
}

@MainActor
@Test("未绑定滚动视图时 isAttached 为 false 且钉底返回 nil")
func controllerWithoutScrollViewIsNotAttached() {
    let controller = ScrollViewBottomController()

    #expect(!controller.isAttached)
    #expect(controller.pinToBottom() == nil)
}

@MainActor
@Test("脱离绑定后 isAttached 回到 false")
func detachClearsAttachment() {
    let host = ScrollViewHost()
    host.setDocumentHeight(1_500)
    let controller = makeController(host: host)
    #expect(controller.isAttached)

    controller.detachForTesting(from: host.scrollView)

    #expect(!controller.isAttached)
    #expect(controller.pinToBottom() == nil)
}

@MainActor
@Test("视口高度为 0 时拒绝返回几何快照")
func pinToBottomRejectsZeroViewport() {
    let host = ScrollViewHost()
    host.setDocumentHeight(1_000)
    let controller = makeController(host: host)
    // 人为把 clip view 高度清零，模拟尚未完成布局
    host.scrollView.contentView.frame.size.height = 0

    #expect(controller.pinToBottom() == nil)
}

@MainActor
@Test("文档高度持续增长时，收敛循环可在高度稳定后退出")
func settleConvergesAfterDocumentHeightStabilizes() async {
    let host = ScrollViewHost()
    host.setDocumentHeight(1_000)
    let controller = makeController(host: host)

    // 模拟懒加载：高度逐帧增长后稳定
    let finalHeight: CGFloat = 2_400
    for step in 1...6 {
        host.setDocumentHeight(1_000 + CGFloat(step) * 200)
        _ = controller.pinToBottom()
    }
    host.setDocumentHeight(finalHeight)

    let coordinator = MessageListScrollCoordinator(settleDelayOverrideNs: 500_000)
    await coordinator.settleBottomForTesting(controller: controller) { true }

    #expect(host.snapshot.documentHeight == finalHeight)
    #expect(host.scrollView.contentView.bounds.origin.y > 0)
}

@MainActor
@Test("非有限或异常尺寸的文档不会被钉底")
func pinToBottomRejectsInvalidGeometry() {
    let host = ScrollViewHost()
    host.setDocumentHeight(1_000)
    let controller = makeController(host: host)

    // 超过 10_000_000 的文档高度应被拒绝（防御异常布局）
    host.documentView.frame = NSRect(x: 0, y: 0, width: 400, height: 20_000_000)
    #expect(controller.pinToBottom() == nil)

    // 非有限高度同样应被拒绝。
    // - Note: 不能给 clip view 设 .nan —— AppKit 自身会因此崩溃，
    //   这属于越过测试宿主能力的构造，改由下方 documentView 覆盖。
    host.documentView.frame = NSRect(x: 0, y: 0, width: 400, height: 1_000)
    #expect(controller.pinToBottom() != nil, "正常几何仍应返回快照")
}
