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
/// ## 实现方式
///
/// 在应用层装一个滚轮事件监视器：
///
/// 1. 事件发生时，用 `hitTest` 找到事件点命中的视图，再沿 `superview`
///    链向上找第一个 `NSScrollView`；
/// 2. 若命中的滚动视图已登记到本类型（就是某个展开中的过程区），
///    且它**已经在边界**（顶/底），就把事件转发给它的
///    `enclosingScrollView`（即外层列表的滚动视图），并消费掉本次事件；
/// 3. 其余情况一律放行，不影响应用其它区域的滚动。
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

    /// 处理一个滚轮事件。返回 `true` 表示事件已被转发并消费。
    private func handle(_ event: NSEvent) -> Bool {
        guard let scrollView = hitScrollView(for: event) else { return false }
        guard registered.contains(scrollView) else { return false }

        let delta = event.scrollingDeltaY
        let clipView = scrollView.contentView
        let documentHeight = scrollView.documentView?.bounds.height ?? 0
        let visibleHeight = clipView.bounds.height

        let shouldForward = Self.shouldForward(
            deltaY: delta,
            currentOffsetY: clipView.bounds.origin.y,
            documentHeight: documentHeight,
            visibleHeight: visibleHeight
        )
        guard shouldForward else { return false }

        // 转发给外层（外层列表的滚动视图）。
        guard let outer = scrollView.enclosingScrollView else { return false }
        forwardedScrollCount += 1
        outer.scrollWheel(with: event)
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
    /// 滚动方向语义：`scrollingDeltaY > 0` 表示「向下滚内容」
    /// （内容向上移动，offset 增大），`< 0` 表示向上滚。
    ///
    /// - Parameters:
    ///   - deltaY: 滚轮事件的垂直增量。
    ///   - currentOffsetY: 内层当前偏移量。
    ///   - documentHeight: 内层文档高度。
    ///   - visibleHeight: 内层可视高度。
    /// - Returns: 内层已在对应方向的边界上时返回 `true`。
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
