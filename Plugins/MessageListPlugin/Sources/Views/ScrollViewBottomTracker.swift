import AppKit
import SwiftUI

/// 通过观察底层 `NSScrollView` 的滚动位置来判断「用户是否停在列表底部」,
/// **完全替代** SwiftUI 的 `GeometryReader` + `PreferenceKey` 方案。
///
/// ## 为什么需要它
///
/// 旧方案在 `LazyVStack` 末尾挂一个 `GeometryReader { Color.clear.preference(...) }`,
/// 报告锚点的全局 maxY。在流式场景下(助手回复行高随 token 连续增长),这个锚点的
/// 全局坐标**每帧都在变**,导致:
/// - 该锚点作为 LazyVStack 子视图参与布局,其变化触发 `LazySubviewPlacements`
///   反复 `makeSizeChangeTranslation`(尺寸变更平移);
/// - `MessageListBottomAnchorPositionKey` 每帧把新值推入 AttributeGraph 偏好拓扑;
/// - 即便回调里不再写 `@State`,偏好传播本身仍让 LazyStack 永不收敛 →
///   主线程 100% CPU 活锁,runloop 不排空 autorelease pool → 内存单调上涨。
///
/// 本类型把「是否在底部」的判定从 SwiftUI 布局/偏好系统里**完全剥离**,改为由
/// AppKit 的 `NSClipView.boundsDidChangeNotification` 驱动(仅在滚动时触发,
/// 流式行高度变化不会触发),彻底切断反馈环。思路与 AppKit 版本的
/// `AppKitScrollAnchor` 一致。
///
/// ## 线程与 invalidation
///
/// 观察者在主队列回调;闭包写入的内容(`AtBottomBox`)刻意不实现 `ObservableObject`,
/// 因此**不会**触发 SwiftUI invalidation —— 这是切断反馈环的关键之一。
///
/// ## 布局影响
///
/// `makeNSView` 返回一个零尺寸、不参与布局的 NSView,仅用于拿到 window 后向上
/// 查找 `enclosingScrollView`。它不会贡献任何尺寸或参与 SwiftUI 的尺寸协商。
struct ScrollViewBottomTracker: NSViewRepresentable {
    /// 「是否在底部」布尔值翻转时回调。仅在真正翻转时调用,避免高频无意义触发。
    let onChange: (Bool) -> Void

    func makeNSView(context: Context) -> TrackerView {
        let view = TrackerView()
        // 经 coordinator 转发回调;updateNSView 会把最新 onChange 同步给 coordinator。
        view.onChange = { [weak coordinator = context.coordinator] atBottom in
            coordinator?.onChange(atBottom)
        }
        return view
    }

    func updateNSView(_ nsView: TrackerView, context: Context) {
        // 故意不做任何尺寸/几何相关工作 —— 这里一旦触碰布局就会重新进入
        // SwiftUI 的尺寸协商,可能复活反馈环。仅同步回调句柄。
        context.coordinator.onChange = onChange
    }

    static func dismantleNSView(_ nsView: TrackerView, coordinator: Coordinator) {
        nsView.stopObserving()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange)
    }

    final class Coordinator {
        var onChange: (Bool) -> Void
        init(onChange: @escaping (Bool) -> Void) {
            self.onChange = onChange
        }
    }
}

/// 承载观察逻辑的 NSView。零尺寸、不绘制、不参与布局尺寸协商。
@MainActor
final class TrackerView: NSView {
    fileprivate var onChange: ((Bool) -> Void)?
    private var observation: NSObjectProtocol?
    private weak var observedScrollView: NSScrollView?
    /// 上一次报告的「是否在底部」,用于迟滞判定、避免无谓回调。
    private var lastAtBottom: Bool = true

    override init(frame frameRect: NSRect) {
        super.init(frame: .zero)
        // 不绘制、不参与命中测试,纯粹作为「挂在视图树里用来找 scrollView」的锚点。
        wantsLayer = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            attachIfNeeded()
        } else {
            stopObserving()
        }
    }

    private func attachIfNeeded() {
        guard observation == nil,
              let scrollView = enclosingScrollView,
              scrollView !== observedScrollView else { return }

        stopObserving()
        observedScrollView = scrollView
        let clipView = scrollView.contentView
        // postsBoundsChangedNotifications 默认对 NSClipView 为 true,显式确保。
        clipView.postsBoundsChangedNotifications = true
        observation = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: clipView,
            queue: .main
        ) { [weak self] _ in
            // NotificationCenter 回调不在 MainActor 上下文里,dispatch 回主线程。
            Task { @MainActor [weak self] in
                self?.reevaluate()
            }
        }
        // 附着后立刻评估一次,把初始状态同步给回调。
        reevaluate()
    }

    fileprivate func stopObserving() {
        if let observation {
            NotificationCenter.default.removeObserver(observation)
            self.observation = nil
        }
        observedScrollView = nil
    }

    private func reevaluate() {
        guard let scrollView = observedScrollView,
              let documentView = scrollView.documentView else { return }
        let documentHeight = documentView.bounds.height
        let visibleHeight = scrollView.contentView.bounds.height
        let offsetY = scrollView.contentView.bounds.origin.y
        guard documentHeight.isFinite, visibleHeight.isFinite,
              documentHeight < 10_000_000, visibleHeight > 0 else { return }

        let distance = documentHeight - (offsetY + visibleHeight)
        // 迟滞:已在底部时用更宽容的离开阈值,不在底部时用更严格的进入阈值,
        // 避免在容差边界抖动时反复翻转。
        let tolerance = lastAtBottom
            ? MessageListScrollCoordinator.bottomLeaveTolerance
            : MessageListScrollCoordinator.bottomEnterTolerance
        let atBottom = distance <= tolerance

        guard atBottom != lastAtBottom else { return }
        lastAtBottom = atBottom
        onChange?(atBottom)
    }

    /// 切换会话/重置滚动位置时由外部调用,把判定重置回「在底部」。
    /// (当前由 `atBottomBox.value = true` 直接重置,此处保留以备需要。)
    fileprivate func resetToBottom() {
        lastAtBottom = true
    }
}
