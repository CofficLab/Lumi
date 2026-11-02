import AppKit
import SwiftUI

/// 过程折叠区的**滚动接力**。
///
/// ## 为什么需要它
///
/// macOS 的 `NSScrollView` **默认没有滚动链**：内层到底后继续拖动，
/// 事件被内层吃掉，外层列表纹丝不动。用户在展开的过程区里滚到底后
/// 再想往下看，只能先把鼠标移出折叠区 —— 手感上像是「卡住了」。
///
/// ## 方向语义：SwiftUI 内层与原生外层是**相反**的
///
/// 这是本类型存在的前提，也是最容易搞错的地方。实测（macOS）：
///
/// | 接收方 | `deltaY = -40`（触控板向上滑）时 offset 的变化 |
/// | --- | --- |
/// | 原生 `NSScrollView` | `+40`（offset 增大，内容向下走） |
/// | SwiftUI `HostingScrollView` | **`-40`**（offset 减小，内容向上走） |
///
/// 换句话说，SwiftUI 内层是 **`offset -= deltaY`**，原生是 `offset += deltaY`。
///
/// ### 这为什么导致「折叠区滚不动」
///
/// 过程折叠区展开后自动**钉在底部**（`offset = 文档高 − 视口高`）。
///
/// 用户想往上翻看更早的过程内容时（触控板向上滑，`deltaY < 0`）：
///
/// - SwiftUI 语义要求 `offset` **增大**；
/// - 但 `offset` 已经在最大值 → 没有空间可增 → **内层纹丝不动**；
/// - 事件继续往下传 → 被**外层原生 List** 消费 → 外层向上滚 →
///
/// > 「触发的是外部的滚动条，它自己根本不滚动。」
///
/// 也就是说，内层「滚不动」不是它坏了，而是**方向语义相反**，
/// 向上滚恰好撞在它唯一能走的方向的边界上。
///
/// ## 实现方式
///
/// 在应用层装一个滚轮事件监视器，命中已登记的内层时**主动驱动**它：
///
/// 1. 事件发生时，用 `hitTest` 找到事件点命中的视图，再沿 `superview`
///    链向上找第一个 `NSScrollView`；
/// 2. 若命中的滚动视图已登记到本类型（就是某个展开中的过程区），
///    就按**原生**方向语义直接改它的 `clipView.bounds`；
/// 3. 内层已在对应方向的边界上时，把剩余增量转发给它的
///    `enclosingScrollView`（即外层列表的滚动视图），并消费掉本次事件。
///
/// - Important: **不能只是「放行」**让 SwiftUI 自己的手势处理。
///   SwiftUI 的手势路径对触控板的处理与原生不同（且嵌套在 `List` 行里时
///   常常不生效），实测放行后内层偏移纹丝不动。主动驱动是唯一可靠路径。
/// - Important: 我们对内层**一律用原生语义**（`offset += deltaY`），
///   不沿用 SwiftUI 自己的反向语义 —— 否则「向上滑看更早的内容」
///   会变成「向下看更晚的内容」。转发给外层时直接交出原事件即可，
///   原生滚动视图自己会按原生语义处理。
///
/// ## 为什么用应用层监视器而不是子类化 NSScrollView
///
/// SwiftUI 的 `ScrollView` 内部是私有实现（`HostingScrollView`），
/// 无法替换成自己的子类 —— 而自建 `NSScrollView` + `NSHostingView`
/// 需要自己测量内容高度（`NSHostingView.fittingSize` 不随宽度变化，
/// 对换行文本会给出错误高度），风险更高。应用层监视器不触碰渲染链路。
///
/// ## 事件命中判定
///
/// 用 `hitTest` 找到事件点命中的视图，再沿 `superview` 链向上找
/// 第一个 `NSScrollView`。注意**不能**只取「鼠标位置所在的滚动视图」：
/// 事件点常常落在内容的子视图上（Markdown 文本、代码块等），
/// 直接取会拿到外层列表而不是行内的折叠区。
@MainActor
final class ProcessSectionScrollRelay {
    /// 全局共享实例：接力是「应用级」的能力（事件监视器装在 NSApp 上）。
    static let shared = ProcessSectionScrollRelay()

    /// 已登记的折叠区内层滚动视图（弱引用，避免持有已拆除的行）。
    private var registered = NSHashTable<NSScrollView>.weakObjects()

    /// 事件监视器句柄。
    private var monitor: Any?

    /// app 终止通知的观察句柄。
    private var terminationObservation: NSObjectProtocol?

    /// 已转发的次数（供单测断言）。
    private(set) var forwardedScrollCount = 0

    /// 已由本类型主动驱动内层滚动的次数（供单测断言）。
    private(set) var innerScrolledCount = 0

    private init() {}

    // MARK: - 登记

    /// 登记一个折叠区内层滚动视图。
    func register(_ scrollView: NSScrollView) {
        guard !registered.contains(scrollView) else { return }
        registered.add(scrollView)
        startMonitorIfNeeded()
    }

    /// 注销一个折叠区内层滚动视图。
    ///
    /// - Important: 最后一个观察者注销时**移除事件监视器**。
    ///   `NSEvent.addLocalMonitorForEvents` 注册的监视器会让 app 无法
    ///   正常退出（实测：UI 测试 teardown 报「Failed to terminate」，
    ///   禁用监视器后恢复）—— 监视器持有 app 的事件循环引用。
    ///   折叠区全部收起时没有接力需求，监视器就该消失。
    func unregister(_ scrollView: NSScrollView) {
        registered.remove(scrollView)
        if registered.count == 0 {
            stopMonitoring()
        }
    }

    /// 该滚动视图是否已登记。
    func isRegistered(_ scrollView: NSScrollView) -> Bool {
        registered.contains(scrollView)
    }

    /// 清空登记并移除监视器（**仅供测试**）。
    ///
    /// - Note: 进程级单例的状态会跨用例残留 —— 上一条用例渲染的
    ///   `BoundedProcessSection` 可能还没被 SwiftUI 拆除（拆除是异步的），
    ///   它的内层滚动视图仍登记在表里。于是「最后一个观察者注销后移除
    ///   监视器」这类断言会因残留登记而失败。
    ///   测试用例应当先调用它把状态归零。
    func resetForTesting() {
        // `NSHashTable` 没有 `removeAll()`，逐个移除。
        for scrollView in registered.allObjects {
            registered.remove(scrollView)
        }
        stopMonitoring()
    }

    /// 滚轮事件监视器当前是否处于启用状态。
    ///
    /// - Important: 供测试断言监视器的生命周期。监视器残留会让 app
    ///   无法正常退出（见 ``stopMonitoring()``）。
    var isMonitoring: Bool {
        monitor != nil
    }

    // MARK: - 事件监视

    private func startMonitorIfNeeded() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self else { return event }
            // 返回 nil 表示事件已被消费，不再往下传。
            return self.handle(event) ? nil : event
        }
        observeAppTerminationIfNeeded()
    }

    /// 监听 app 终止，移除事件监视器。
    ///
    /// - Important: `NSEvent.addLocalMonitorForEvents` 注册的监视器持有 app
    ///   的事件循环引用，app 退出时若监视器还在，app 可能无法正常结束
    ///   （实测：UI 测试 teardown 报「Failed to terminate」，禁用监视器后
    ///   恢复正常）。因此除了「最后一个观察者注销时移除」，还要在 app
    ///   终止时兜底移除 —— 用户完全可能让折叠区一直展开着直到退出。
    private func observeAppTerminationIfNeeded() {
        guard terminationObservation == nil else { return }
        terminationObservation = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.stopMonitoring()
        }
    }

    /// 停止监视（供测试与 teardown 使用）。
    func stopMonitoring() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        if let terminationObservation {
            NotificationCenter.default.removeObserver(terminationObservation)
            self.terminationObservation = nil
        }
    }

    /// 处理一个滚轮事件。返回 `true` 表示事件已被消费。
    private func handle(_ event: NSEvent) -> Bool {
        guard let scrollView = hitScrollView(for: event) else { return false }
        guard registered.contains(scrollView) else { return false }

        let delta = event.scrollingDeltaY
        guard delta != 0 else { return false }

        // 主动驱动内层滚动。
        //
        // - Important: 必须**主动驱动**，不能只是放行给 SwiftUI 的手势。
        //   实测放行后内层偏移纹丝不动 —— SwiftUI 的手势路径在嵌套于
        //   `List` 行时并不处理这类滚轮事件。
        //
        // - Important: 方向用**原生**语义（`offset += deltaY`），
        //   而不是 SwiftUI 自己的语义。理由见 ``scrollInner(_:deltaY:)``。
        let consumed = scrollInner(scrollView, deltaY: delta)
        if consumed {
            innerScrolledCount += 1
            return true
        }

        // 内层已在对应方向的边界上：把剩余增量让给外层。
        guard let outer = scrollView.enclosingScrollView else { return false }
        forwardedScrollCount += 1
        outer.scrollWheel(with: event)
        return true
    }

    /// 主动把滚轮增量应用到内层滚动视图。
    ///
    /// - Parameter deltaY: 事件的垂直增量。
    /// - Returns: 内层**确实**滚动了时返回 `true`；已在边界上返回 `false`
    ///   （由调用方决定是否接力给外层）。
    ///
    /// - Important: 方向用**原生**语义：`offset += deltaY`。
    ///
    ///   SwiftUI 自己的 `HostingScrollView.scrollWheel(with:)` 用的是
    ///   **相反**的方向（`offset -= deltaY`，实测：deltaY=-40 让 offset
    ///   从 330.5 变成 370.5）。若沿用它，用户「向上滑看更早的内容」
    ///   （deltaY < 0）会让 offset **增大** —— 也就是看**更晚**的内容。
    ///   而过程折叠区展开时钉在**底部**（offset 已是最大值），
    ///   于是向上滑恰好撞在边界上 → 内层纹丝不动 → 事件落到外层 List
    ///   → 「外层滚动条动、内层不动」。
    ///
    ///   这里直接改 `clipView.bounds`，方向由**我们**决定，不受 SwiftUI
    ///   内部语义影响，也就不会与「内容上下」的方向对调。
    ///
    /// - Important: 直接改 `clipView.bounds` 而不是调用
    ///   `scrollWheel(with:)` —— 后者对 SwiftUI 的 `HostingScrollView`
    ///   无效（实测：调用后偏移不变）。这与自动钉底
    ///   （`BoundedProcessSectionScrollObserver.pinToBottom`）同一范式。
    func scrollInner(_ scrollView: NSScrollView, deltaY: CGFloat) -> Bool {
        let clipView = scrollView.contentView
        let documentHeight = scrollView.documentView?.bounds.height ?? 0
        let visibleHeight = clipView.bounds.height
        guard documentHeight.isFinite,
              visibleHeight.isFinite,
              visibleHeight > 0 else {
            return false
        }

        let maxOffsetY = max(0, documentHeight - visibleHeight)
        let currentOffsetY = clipView.bounds.origin.y
        // 原生语义：offset += deltaY。
        let targetOffsetY = currentOffsetY + deltaY
        let clamped = min(max(targetOffsetY, 0), maxOffsetY)
        guard abs(clamped - currentOffsetY) > 0.5 else { return false }

        var bounds = clipView.bounds
        bounds.origin.y = clamped
        clipView.bounds = bounds
        scrollView.reflectScrolledClipView(clipView)
        return true
    }

    /// 找到事件点命中的滚动视图。
    ///
    /// - Important: 必须用 `hitTest` 找**视图**，再沿 `superview` 链向上找
    ///   滚动视图。事件点常常落在内容的子视图上（文本、代码块等），
    ///   直接取「鼠标下的滚动视图」会拿到外层列表。
    private func hitScrollView(for event: NSEvent) -> NSScrollView? {
        guard let window = event.window ?? NSApp.keyWindow ?? NSApp.mainWindow else {
            return nil
        }
        // `locationInWindow` 已经是窗口坐标；`convertPoint(fromScreen:)` 是给
        // 屏幕坐标用的，这里不能再转一次。
        let location = event.locationInWindow
        guard let hit = window.contentView?.hitTest(location) else { return nil }

        var current: NSView? = hit
        while let candidate = current {
            if let scrollView = candidate as? NSScrollView {
                return scrollView
            }
            current = candidate.superview
        }
        return nil
    }

    // MARK: - 边界判定

    /// 是否应把滚动增量让给外层。
    ///
    /// - Important: 这里用的是**原生**语义（`offset += deltaY`），
    ///   因为判定对象是外层列表（原生 `ListCoreScrollView`）。
    ///   内层（SwiftUI）的方向语义相反，见 ``scrollInner(_:deltaY:)``。
    ///
    /// 滚动方向语义：`scrollingDeltaY > 0` 表示「向下滚内容」
    /// （内容向上移动，offset 增大），`< 0` 表示向上滚。
    ///
    /// - Parameters:
    ///   - deltaY: 滚轮事件的垂直增量。
    ///   - currentOffsetY: 偏移量。
    ///   - documentHeight: 文档高度。
    ///   - visibleHeight: 可视高度。
    /// - Returns: 已在对应方向的边界上时返回 `true`。
    static func shouldForward(
        deltaY: CGFloat,
        currentOffsetY: CGFloat,
        documentHeight: CGFloat,
        visibleHeight: CGFloat
    ) -> Bool {
        guard deltaY != 0 else { return false }
        guard documentHeight.isFinite, visibleHeight.isFinite, visibleHeight > 0 else {
            return false
        }
        let maxOffsetY = max(0, documentHeight - visibleHeight)
        if deltaY > 0 {
            // 向下滚：已到底则让给外层。
            return currentOffsetY >= maxOffsetY - 1
        }
        // 向上滚：已到顶则让给外层。
        return currentOffsetY <= 1
    }
}
