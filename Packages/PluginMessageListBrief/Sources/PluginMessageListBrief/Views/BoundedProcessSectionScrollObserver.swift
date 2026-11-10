import AppKit
import SwiftUI

/// 观察内层滚动视图的两种信号：
///
/// 1. **内容增长**（`documentView.frameDidChangeNotification`）—— 内容变高了；
/// 2. **用户滚动**（`clipView.boundsDidChangeNotification`）—— 用户动了滚动位置。
///
/// ## 为什么这两个信号必须分开看
///
/// 实测（macOS / SwiftUI `ScrollView`）：
///
/// | 场景 | `frameDidChange`（文档） | `boundsDidChange`（视口） |
/// | --- | --- | --- |
/// | 内容变高 | ✅ 触发 | ❌ 不触发 |
/// | 用户滚动 | ❌ 不触发 | ✅ 触发 |
///
/// 两个信号**完全互斥**。这正是实现「内容增长时自动钉底、用户滚动后可打断」
/// 所需要的判据 —— 不必去猜「用户是不是在底部」这种间接推断。
///
/// 对比之下，SwiftUI 自带的 `defaultScrollAnchor(.bottom)` 虽然也能在内容
/// 增长时贴底，但**用户上滚后会被下一次内容增长拽回底部**，无法打断
/// （实测：上滚到 offset=100，内容增长后 offset 变成 1400 = 新的底部）。
/// 因此这里自行实现。
///
/// ## 为什么不用 PreferenceKey 测几何
///
/// `ListV1View` 明确警告过：不要用 `GeometryReader + PreferenceKey` 测量
/// 活跃行的高度 —— 流式 token → 高度 → 布局 → 高度 的反馈环。
/// 同样的道理适用于滚动位置。
struct BoundedProcessSectionScrollObserver: NSViewRepresentable {
    /// 「是否贴底」状态翻转时回调。
    let onAtBottomChange: (Bool) -> Void

    /// 用户主动上滚离开底部时回调（用于打断贴底跟随）。
    let onUserScrolledAway: () -> Void

    /// 是否处于跟随态。内容增长时据此决定要不要钉底。
    ///
    /// - Important: 由 `updateNSView` 从 SwiftUI 侧同步进来。
    var isFollowing: Bool

    init(
        isFollowing: Bool,
        onAtBottomChange: @escaping (Bool) -> Void,
        onUserScrolledAway: @escaping () -> Void
    ) {
        self.isFollowing = isFollowing
        self.onAtBottomChange = onAtBottomChange
        self.onUserScrolledAway = onUserScrolledAway
    }

    func makeNSView(context: Context) -> TrackerView {
        let view = TrackerView()
        view.isFollowing = isFollowing
        view.onAtBottomChange = onAtBottomChange
        view.onUserScrolledAway = onUserScrolledAway
        return view
    }

    func updateNSView(_ nsView: TrackerView, context: Context) {
        nsView.isFollowing = isFollowing
        nsView.onAtBottomChange = onAtBottomChange
        nsView.onUserScrolledAway = onUserScrolledAway
        // 视图刚挂上时尚未完成初始定位：把当前内容钉到底部。
        nsView.requestInitialPinIfNeeded()
    }

    static func dismantleNSView(_ nsView: TrackerView, coordinator: Coordinator) {
        nsView.stopObserving()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var onAtBottomChange: (Bool) -> Void
        var onUserScrolledAway: () -> Void

        init(
            onAtBottomChange: @escaping (Bool) -> Void = { _ in },
            onUserScrolledAway: @escaping () -> Void = {}
        ) {
            self.onAtBottomChange = onAtBottomChange
            self.onUserScrolledAway = onUserScrolledAway
        }
    }

    /// 承载观察逻辑的 NSView。零尺寸、不绘制、不参与布局尺寸协商。
    ///
    /// - Important: 这个视图**必须放在 `ScrollView` 的内容内部**。
    ///   放在 `.background` 里（ScrollView 外面）时，它的
    ///   `enclosingScrollView` 恒为 `nil` —— 因为它根本不在滚动视图的
    ///   视图子树里，观察器会静默失效（实测确认）。放在内容内部时，
    ///   `enclosingScrollView` 立刻拿到 `HostingScrollView`。
    @MainActor
    final class TrackerView: NSView {
        fileprivate var onAtBottomChange: ((Bool) -> Void)?
        fileprivate var onUserScrolledAway: (() -> Void)?

        /// 是否处于跟随态。内容增长时据此决定要不要钉底。
        fileprivate var isFollowing = true

        private var clipObservation: NSObjectProtocol?
        private var documentObservation: NSObjectProtocol?
        private weak var observedScrollView: NSScrollView?
        /// 上一次报告的贴底状态，用于迟滞判定、避免无谓回调。
        private var lastAtBottom = true
        /// 是否已经完成过首次评估。首次评估只同步状态，不判定「用户上滚」。
        private var hasEvaluatedOnce = false
        /// 是否已经完成过一次初始定位（把视图钉到底部）。
        private var hasPerformedInitialPin = false
        /// 是否正在执行钉底。
        ///
        /// - Important: 钉底会修改 `clipView.bounds`，这会**同步**触发
        ///   `boundsDidChangeNotification` —— 若不加这个标志，钉底动作自己
        ///   会被当成「用户上滚」而打断跟随，形成自我打断的死循环。
        private var isPinning = false

        override init(frame frameRect: NSRect) {
            super.init(frame: .zero)
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

        override func viewDidMoveToSuperview() {
            super.viewDidMoveToSuperview()
            attachIfNeeded()
        }

        override func layout() {
            super.layout()
            // 观察者可能晚于视图层级进入；在这里重试，直到拿到祖先滚动视图。
            attachIfNeeded()
        }

        // MARK: - 观察

        private func attachIfNeeded() {
            guard let scrollView = enclosingScrollView else {
                stopObserving()
                return
            }
            guard scrollView !== observedScrollView else { return }
            attach(to: scrollView)
        }

        private func attach(to scrollView: NSScrollView) {
            stopObserving()
            observedScrollView = scrollView
            let clipView = scrollView.contentView
            clipView.postsBoundsChangedNotifications = true

            // 信号 1：用户滚动 → 视口偏移变化。
            //
            // - Important: `queue: nil` = **同步**在 post 线程（主线程）执行。
            //   用 `queue: .main` 会把处理推迟到下一个 runloop 迭代，钉底就
            //   会慢一帧 —— 表现为「内容已经出现了，但视口还没跟上」。
            clipObservation = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: clipView,
                queue: nil
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.handleUserScroll()
                }
            }

            // 信号 2：内容增长 → 文档视图高度变化。
            //
            // - Important: 同样是同步处理。钉底必须在内容变高的**同一刻**
            //   发生，否则新内容会先出现在视口外、再被拽进来 —— 视觉上
            //   就是「闪一下才对齐」。
            if let documentView = scrollView.documentView {
                documentObservation = NotificationCenter.default.addObserver(
                    forName: NSView.frameDidChangeNotification,
                    object: documentView,
                    queue: nil
                ) { [weak self] _ in
                    MainActor.assumeIsolated {
                        self?.handleContentGrew()
                    }
                }
            }

            // 登记到接力表：内层到底时把剩余增量转给外层列表。
            ProcessSectionScrollRelay.shared.register(scrollView)
            reevaluate()
            // 首次挂上：把当前内容钉到底部。
            //
            // - Important: 必须在这里调，不能只依赖 `updateNSView` ——
            //   `updateNSView` 早于 `attach` 执行，那时还拿不到滚动视图。
            requestInitialPinIfNeeded()
        }

        fileprivate func stopObserving() {
            if let clipObservation {
                NotificationCenter.default.removeObserver(clipObservation)
                self.clipObservation = nil
            }
            if let documentObservation {
                NotificationCenter.default.removeObserver(documentObservation)
                self.documentObservation = nil
            }
            if let observedScrollView {
                ProcessSectionScrollRelay.shared.unregister(observedScrollView)
            }
            observedScrollView = nil
            hasEvaluatedOnce = false
            lastAtBottom = true
            hasPerformedInitialPin = false
        }

        /// 内容变高：处于跟随态时钉到底部。
        private func handleContentGrew() {
            guard isFollowing else { return }
            pinToBottom()
            // 高度变化后贴底状态可能改变（例如原本到底，内容变高后就不再到底）。
            reevaluate()
        }

        /// 用户滚动：更新贴底状态；离开底部则打断跟随。
        ///
        /// - Important: 判据是「当前不在底部」，而不是「从底部离开」。
        ///   展开一个内容超长的折叠区时，视口初始就在顶部 —— 这时若要求
        ///   「必须先在底部才能被打断」，用户的上滚就不会被识别成打断意图。
        /// - Important: 钉底动作自身引起的偏移变化由 ``isPinning`` 排除。
        private func handleUserScroll() {
            if isPinning { return }
            let wasAtBottom = lastAtBottom
            reevaluate()
            // 已经在底部 → 可能是钉底动作引起的回弹，不打断。
            if wasAtBottom { return }
            // 不在底部 → 用户主动上滚，打断跟随。
            if !lastAtBottom {
                onUserScrolledAway?()
            }
        }

        /// 重新判定贴底状态。
        ///
        /// 「贴底」的判定用**迟滞**：距离底部小于 1pt 算贴底；
        /// 超过 1pt 才算离开底部。这样用户停在最底部时的轻微抖动
        /// 不会把跟随反复打断。
        private func reevaluate() {
            guard let scrollView = observedScrollView else { return }
            let clipView = scrollView.contentView
            let documentHeight = scrollView.documentView?.bounds.height ?? 0
            let visibleHeight = clipView.bounds.height
            guard documentHeight.isFinite,
                  visibleHeight.isFinite,
                  visibleHeight > 0 else { return }

            let maxOffsetY = max(0, documentHeight - visibleHeight)
            let currentY = clipView.bounds.origin.y
            let atBottom = (maxOffsetY - currentY) <= 1

            hasEvaluatedOnce = true
            if atBottom != lastAtBottom {
                lastAtBottom = atBottom
                onAtBottomChange?(atBottom)
            }
        }

        /// 请求一次初始定位：把视图钉到底部。
        ///
        /// - Important: 展开一个内容超长的折叠区时，SwiftUI 的初始偏移量
        ///   在顶部（offset = 0）。要让「最新内容出现在底部」，必须显式钉一次底。
        /// - Important: **同步**执行，不推迟到下一个 runloop 迭代。
        ///   推迟会让初始定位慢一帧，用户先看到顶部再被拽到底部。
        ///   延后钉底由「内容增长」信号兜底（内容还在解析时会再次变高）。
        func requestInitialPinIfNeeded() {
            guard !hasPerformedInitialPin else { return }
            guard observedScrollView != nil else { return }
            hasPerformedInitialPin = true
            pinToBottom()
        }

        /// 把内层滚动视图钉到底部。
        ///
        /// - Important: 直接改 `clipView.bounds` 而不是用 SwiftUI 的
        ///   `ScrollViewProxy.scrollTo`。原因：后者是**动画式**滚动 ——
        ///   内容连续增长时会一直排队，视觉上变成「追不上」；而且它无法
        ///   区分「内容变高」与「用户滚动」。这里在 AppKit 层同步钉底，
        ///   与 `ScrollViewBottomController.pinToBottom()` 同一范式。
        func pinToBottom() {
            guard let scrollView = observedScrollView,
                  let documentView = scrollView.documentView else { return }
            let clipView = scrollView.contentView
            let documentHeight = documentView.bounds.height
            let visibleHeight = clipView.bounds.height
            guard documentHeight.isFinite,
                  visibleHeight.isFinite,
                  visibleHeight > 0 else { return }

            let maxOffsetY = max(0, documentHeight - visibleHeight)
            var bounds = clipView.bounds
            guard abs(bounds.origin.y - maxOffsetY) > 0.5 else { return }
            isPinning = true
            bounds.origin.y = maxOffsetY
            clipView.bounds = bounds
            scrollView.reflectScrolledClipView(clipView)
            isPinning = false
        }
    }
}
