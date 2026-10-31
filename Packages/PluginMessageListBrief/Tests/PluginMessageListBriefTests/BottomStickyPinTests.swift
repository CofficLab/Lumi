import AppKit
import CoreGraphics
import Foundation
import Testing
@testable import PluginMessageListBrief

/// 等待条件成立，超时则返回 false。
///
/// - Important: 不用固定 sleep。全量测试并行跑时主线程会被其他用例占用，
///   固定 100ms 的等待可能不够让 `DispatchQueue.main.async` 里的钉底动作
///   跑完 → 偶发失败。轮询到条件成立为止才是稳定的。
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

/// 「自动滚动没彻底滚到底」的回归测试。
///
/// ## 用户报告的症状
///
/// 用户已滚动到列表底部，新消息到达后**底部被输入框遮住一小截** ——
/// 列表并没有真正停在内容底沿，而是差了一点点。
///
/// ## 根因
///
/// 「滚到底」这条链路由三段拼成：
///
/// 1. `ListV2View.scrollTick` → `MessageListScrollCoordinator.scheduleScrollToBottomAfterLayout`
///    —— 等一帧让新行布局完成，然后 `proxy.scrollTo(bottomAnchor)`；
/// 2. `MessageListScrollCoordinator.settleBottom`
///    —— 在底层 `NSScrollView` 上反复 `pinToBottom()`，直到**连续 3 帧几何稳定**为止；
/// 3. `ScrollViewBottomTracker`
///    —— 观察 `NSClipView` 的 `boundsDidChangeNotification`，判定「用户是否在底部」。
///
/// 三段**都只在「偏移量变化」时被唤醒**：
///
/// - `settleBottom` 的收敛判据是「`documentHeight` / `visibleHeight` / `offsetY`
///   连续 3 帧不再变化」。一旦被判为稳定，它就退出循环；
/// - `ScrollViewBottomTracker` 观察的是 **clip view 的 bounds**（即偏移），
///   **不观察 document view 的尺寸**。
///
/// 而 `List` 的行高是**事后修正**的：行被物化（materialize）后才会拿到真实高度，
/// Markdown 正文又是**异步解析**的（`MarkdownBlockRenderer` 缓存未命中时
/// `.task` → 后台解析 → 回填，行高随之增长）。这些修正让
/// `documentView.bounds.height` 在**收敛循环已经退出之后**继续增长。
///
/// 文档变高 → 内容底沿跑到视口底**之下** → 没有任何机制把它重新钉回去 →
/// 最后一条消息的底部被输入框遮住一小截。
///
/// 实测（真实 `NSHostingView` + `List`）：文档变高只发
/// `documentView.frameDidChangeNotification`，**不发**
/// `clipView.boundsDidChangeNotification` —— 只观察偏移量的 tracker 收不到信号。
///
/// ## 为什么这条测试能确定性地复现
///
/// 用真实的 `NSScrollView` + `NSClipView` + 文档视图（`ScrollViewHost`），
/// 把「文档在钉底之后继续变高」这一步单独拎出来：
/// 钉底 → 改文档高度 → 等一帧 → 断言偏移量仍在新的底沿。
///
/// 修复前：偏移量停在旧底沿（差值 = 新增高度）→ **底部被挡住**，断言失败。
/// 修复后：tracker 观察到文档变高并重新钉底 → 断言通过。
@MainActor
@Test("内容在钉底之后继续变高：列表必须重新钉住底部，否则底部被输入框遮住")
func bottomStaysPinnedWhenDocumentGrowsAfterSettle() async {
    let host = ScrollViewHost()
    host.setDocumentHeight(1_000)
    let controller = ScrollViewBottomController()
    let tracker = TrackerView()
    tracker.setBottomController(controller)
    // 走与生产路径完全相同的绑定逻辑（安装观察者、接管真实滚动视图）。
    tracker.attachForTesting(to: host.scrollView)

    // 先钉一次底：文档 1000、视口 600 → 偏移应为 400。
    _ = controller.pinToBottom()
    let pinnedOffset = host.scrollView.contentView.bounds.origin.y
    #expect(abs(pinnedOffset - 400) < 0.5, "首次钉底失败：offset=\(pinnedOffset)")

    // List 行高在滚动之后被修正（懒加载行物化 + Markdown 异步解析）→
    // documentView 变高。此处**不**主动滚动，偏移量保持不变。
    host.setDocumentHeight(1_200)

    // 等待 tracker 重新钉底（而不是固定 sleep：全量并行时主线程会被占用）。
    //
    // - Important: `box` 在整个用例期间存活，tracker 不会在 await 期间被释放。
    let repinned = await waitUntil {
        abs(host.scrollView.contentView.bounds.origin.y - 600) < 0.5
    }

    let offsetAfterGrowth = host.scrollView.contentView.bounds.origin.y
    #expect(
        repinned,
        """
        文档在钉底之后变高了 200pt，偏移量却停在 \(offsetAfterGrowth) \
        （正确值应为 600）。内容底沿因此落到视口底之下，底部被输入框遮住。
        """
    )
    // 让 tracker 的最后一次使用落在 await 之后，ARC 不会提前释放它。
    _ = tracker.lastReportedAtBottomForTesting
}

/// 文档连续变高时，每一轮都要重新钉底 —— 只有最后一帧的位置算数。
@MainActor
@Test("内容连续变高：每一轮增长后都必须重新钉底")
func bottomStaysPinnedAcrossConsecutiveGrowths() async {
    let host = ScrollViewHost()
    host.setDocumentHeight(1_000)
    let controller = ScrollViewBottomController()
    let tracker = TrackerView()
    tracker.setBottomController(controller)
    tracker.attachForTesting(to: host.scrollView)

    _ = controller.pinToBottom()

    for height in [1_100.0, 1_200.0, 1_300.0] as [CGFloat] {
        host.setDocumentHeight(height)
        // 每一轮都要等到钉底完成，再进入下一轮。
        let expected = height - 600
        _ = await waitUntil {
            abs(host.scrollView.contentView.bounds.origin.y - expected) < 0.5
        }
    }

    let offset = host.scrollView.contentView.bounds.origin.y
    #expect(
        abs(offset - 700) < 0.5,
        "连续增长后偏移量停在 \(offset)，正确值应为 700（1300 - 600）"
    )
    _ = tracker.lastReportedAtBottomForTesting
}

/// 文档变高后必须**仍然**判定为「在底部」。
///
/// 这是症状的另一半：若此时把 `atBottomBox` 翻成 false，
/// **后续**新消息就彻底不再跟随滚到底了。
@MainActor
@Test("内容在钉底之后变高：底部状态必须保持为 true")
func bottomStateStaysTrueAfterDocumentGrowth() async {
    let host = ScrollViewHost()
    host.setDocumentHeight(1_000)
    let controller = ScrollViewBottomController()
    let tracker = TrackerView()
    tracker.setBottomController(controller)

    var reported: [Bool] = []
    tracker.onChangeForTesting = { reported.append($0) }
    tracker.attachForTesting(to: host.scrollView)

    _ = controller.pinToBottom()
    // 等 tracker 处理完这次钉底（偏移应到 400 = 1000 - 600）。
    _ = await waitUntil {
        abs(host.scrollView.contentView.bounds.origin.y - 400) < 0.5
    }

    // 附着时列表尚未钉底，tracker 会先报一次 false（这是正确的）。
    // 只关注「变高之后」的回调序列。
    reported.removeAll()

    // 文档变高 400pt：远超 `bottomLeaveTolerance`（96）。
    host.setDocumentHeight(1_400)
    // 等待 tracker 完成重新钉底（偏移应到 800 = 1400 - 600）。
    _ = await waitUntil {
        abs(host.scrollView.contentView.bounds.origin.y - 800) < 0.5
    }

    #expect(
        tracker.lastReportedAtBottomForTesting,
        "文档变高后底部状态变成了 false，后续新消息将不再跟随滚到底"
    )
    #expect(
        !reported.contains(false),
        "文档变高不应把底部状态翻成 false，实际回调序列：\(reported)"
    )
}

/// 用户已经上滚时，文档增长**不得**把列表拽回底部。
///
/// 这是「粘底」策略的另一半：只有「我们认为用户仍在底部」时才跟随。
@MainActor
@Test("用户已上滚：文档变高不得把列表拽回底部")
func bottomIsNotYankedBackWhenUserScrolledAway() async {
    let host = ScrollViewHost()
    host.setDocumentHeight(2_000)
    let controller = ScrollViewBottomController()
    let tracker = TrackerView()
    tracker.setBottomController(controller)
    tracker.attachForTesting(to: host.scrollView)

    // 模拟用户上滚：偏移回到 0，距离底沿 1400 → tracker 判定「不在底部」。
    host.scrollView.contentView.bounds.origin.y = 0
    host.scrollView.reflectScrolledClipView(host.scrollView.contentView)
    // 等 tracker 处理完这次偏移变化（判定为「不在底部」）。
    _ = await waitUntil { !tracker.lastReportedAtBottomForTesting }

    let offsetBeforeGrowth = host.scrollView.contentView.bounds.origin.y

    // 文档继续变高（用户在读历史，内容在后台增长）。
    host.setDocumentHeight(2_500)
    // 等 tracker 处理完文档尺寸变化（应当什么都不做）。
    _ = await waitUntil {
        host.scrollView.contentView.bounds.origin.y == offsetBeforeGrowth
    }

    let offsetAfterGrowth = host.scrollView.contentView.bounds.origin.y
    #expect(
        abs(offsetAfterGrowth - offsetBeforeGrowth) < 0.5,
        "用户已上滚，文档变高却把列表拽回了底部（offset 从 \(offsetBeforeGrowth) 变成 \(offsetAfterGrowth)）"
    )
}

/// 解绑之后不得再自动钉底。
///
/// 保证 tracker 只在绑定期间生效 —— 换会话重建 `List` 时，
/// 旧 tracker 不应继续操作已经不属于它的滚动视图。
@MainActor
@Test("解绑后：文档变高不得再被自动钉底")
func noAutoPinAfterDetach() async {
    let host = ScrollViewHost()
    host.setDocumentHeight(1_000)
    let controller = ScrollViewBottomController()
    let tracker = TrackerView()
    tracker.setBottomController(controller)
    tracker.attachForTesting(to: host.scrollView)

    _ = controller.pinToBottom()
    let pinnedOffset = host.scrollView.contentView.bounds.origin.y

    tracker.detachForTesting()

    host.setDocumentHeight(1_200)
    // 负面断言：必须等满一段时间，确认「没有发生任何钉底」。
    // 用 waitUntil 的超时语义：条件在整个窗口内都不成立才算通过。
    let didPin = await waitUntil(timeout: 0.3) {
        abs(host.scrollView.contentView.bounds.origin.y - pinnedOffset) > 0.5
    }

    let offsetAfterGrowth = host.scrollView.contentView.bounds.origin.y
    #expect(
        !didPin,
        "解绑后仍被自动钉底（offset 从 \(pinnedOffset) 变成 \(offsetAfterGrowth)）"
    )
    _ = tracker.lastReportedAtBottomForTesting
}
