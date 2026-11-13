import AppKit
import Foundation
import Testing
@testable import PluginMessageListZCode

/// `ScrollViewBottomTracker` 的滚动视图发现契约测试。
///
/// ## 背景（issue #1301）
///
/// Tracker 挂在 `List` 的 `.background` 上，在 macOS 上它是消息列表
/// `NSScrollView` 的**兄弟**而不是后代，因此：
///
/// - `enclosingScrollView` 恒为 nil；
/// - 向上遍历父视图链也找不到 `NSScrollView`。
///
/// 结果 `findOwningScrollView()` 只能走兜底路径：**递归遍历整个 window 的
/// NSView 层级**。这个代价是 O(window views) 的 —— 长会话下窗口里有成千上万个
/// 已物化的消息行视图。
///
/// 修复前 `attachIfNeeded()` 先做发现、后做身份守卫，于是**每次 layout 失效**
/// （窗口缩放拖动时每帧一次）都要重付一次全窗口扫描。
///
/// ## 不变式
///
/// 1. 已绑定到本 window 内有效的滚动视图时，重复 layout **不再**触发扫描；
/// 2. 解绑之后仍能重新绑定；
/// 3. 同一 window 内的重复发现走缓存，不重复扫描。
@MainActor
@Suite("ZCode 底部追踪器的滚动视图发现")
struct ZCodeBottomTrackerDiscoveryTests {

    /// 构造一个「tracker 与消息列表是兄弟」的真实 window 场景。
    ///
    /// - Important: 必须用真实 `NSWindow`：兜底扫描读的是 `window.contentView`，
    ///   没有 window 就走不到那条路径，测试会变成空断言。
    private func makeSiblingScene() -> (window: NSWindow, scrollView: NSScrollView) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1_000, height: 800),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 1_000, height: 800))
        window.contentView?.addSubview(container)

        // 消息列表：宽度 >= 400 才会被兜底扫描选中（列表栏只有 240）。
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 600, height: 600))
        scrollView.documentView = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 1_000))
        container.addSubview(scrollView)

        // Tracker 是 scrollView 的**兄弟**，与生产路径一致。
        let tracker = TrackerView(frame: .zero)
        container.addSubview(tracker)

        return (window, scrollView)
    }

    @Test("首次发现会绑定到消息列表的滚动视图")
    func firstDiscoveryBindsToMessageList() {
        let (window, scrollView) = makeSiblingScene()
        let tracker = TrackerView(frame: .zero)
        window.contentView?.subviews.first?.addSubview(tracker)

        tracker.attachIfNeededForTesting()

        #expect(tracker.discoveryScanCountForTesting == 1, "首次发现应触发一次扫描")
        #expect(tracker.observedScrollViewForTesting === scrollView)
    }

    @Test("已附着后重复 layout 不再触发全窗口扫描")
    func repeatedLayoutDoesNotRescan() {
        let (window, scrollView) = makeSiblingScene()
        let tracker = TrackerView(frame: .zero)
        window.contentView?.subviews.first?.addSubview(tracker)

        tracker.attachIfNeededForTesting()
        #expect(tracker.discoveryScanCountForTesting == 1)

        // 模拟后续多次 layout 失效（窗口缩放拖动时每帧一次）。
        for _ in 0..<50 {
            tracker.attachIfNeededForTesting()
        }

        #expect(
            tracker.discoveryScanCountForTesting == 1,
            "已附着后重复 layout 不得再扫描窗口层级"
        )
        #expect(tracker.observedScrollViewForTesting === scrollView)
    }

    @Test("解绑之后仍能重新绑定")
    func detachAllowsRebinding() {
        let (window, scrollView) = makeSiblingScene()
        let tracker = TrackerView(frame: .zero)
        window.contentView?.subviews.first?.addSubview(tracker)

        tracker.attachIfNeededForTesting()
        tracker.detachForTesting()
        tracker.attachIfNeededForTesting()

        #expect(tracker.observedScrollViewForTesting === scrollView)
    }

    @Test("同一 window 内的重复发现走缓存，不重复扫描")
    func repeatedDiscoveryWithinSameWindowUsesCache() {
        let (window, scrollView) = makeSiblingScene()
        let tracker = TrackerView(frame: .zero)
        window.contentView?.subviews.first?.addSubview(tracker)

        tracker.attachIfNeededForTesting()
        #expect(tracker.discoveryScanCountForTesting == 1)

        // 解绑后守卫失效，会重跑发现 —— 但同一 window 内应命中缓存。
        tracker.detachForTesting()
        tracker.attachIfNeededForTesting()

        #expect(
            tracker.discoveryScanCountForTesting == 1,
            "同一 window 内的重复发现应命中缓存，不重复扫描"
        )
        #expect(tracker.observedScrollViewForTesting === scrollView)
    }
}
