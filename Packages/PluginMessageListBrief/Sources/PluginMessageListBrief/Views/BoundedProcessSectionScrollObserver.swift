import AppKit
import SwiftUI

/// 观察**内层**滚动视图的位置，回报「是否贴底」，
/// 并把它登记到滚动接力表（内层到底时把剩余增量转给外层列表）。
///
/// ## 为什么不用 PreferenceKey
///
/// `ListV1View` 明确警告过：不要用 `GeometryReader + PreferenceKey` 测量
/// 活跃行的高度 —— 流式 token → 高度 → 布局 → 高度 的反馈环。
/// 同样的道理适用于「是否贴底」：锚点的全局坐标在流式期间每帧都在变。
///
/// 这里改为由 AppKit 的 `NSClipView.boundsDidChangeNotification` 驱动：
/// 只有**真正滚动**时才会触发，流式导致的行高变化不会触发。
///
/// ## 「用户上滚」与「初始就在顶部」的区分
///
/// 展开一个内容超长的折叠区时，初始偏移量就在顶部（offset = 0）。
/// 这时若把「不在底部」当成「用户上滚」，贴底跟随会在第一次内容增长时
/// 就被打断 —— 恰恰违背「自动跟随底部（可被用户打断）」的预期。
///
/// 因此只有**非首次**评估中出现的「离开底部」才算用户主动上滚：
/// 首次评估只用于同步初始状态。
struct BoundedProcessSectionScrollObserver: NSViewRepresentable {
    /// 「是否贴底」状态翻转时回调。
    let onAtBottomChange: (Bool) -> Void

    /// 用户主动上滚离开底部时回调（用于打断贴底跟随）。
    let onUserScrolledAway: () -> Void

    func makeNSView(context: Context) -> TrackerView {
        let view = TrackerView()
        view.onAtBottomChange = onAtBottomChange
        view.onUserScrolledAway = onUserScrolledAway
        return view
    }

    func updateNSView(_ nsView: TrackerView, context: Context) {
        nsView.onAtBottomChange = onAtBottomChange
        nsView.onUserScrolledAway = onUserScrolledAway
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
    @MainActor
    final class TrackerView: NSView {
        fileprivate var onAtBottomChange: ((Bool) -> Void)?
        fileprivate var onUserScrolledAway: (() -> Void)?

        private var observation: NSObjectProtocol?
        private weak var observedScrollView: NSScrollView?
        /// 上一次报告的贴底状态，用于迟滞判定、避免无谓回调。
        private var lastAtBottom = true
        /// 是否已经完成过首次评估。首次评估只同步状态，不判定「用户上滚」。
        private var hasEvaluatedOnce = false

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
            // 观察者作为 SwiftUI background 安装，可能在进入视图层级之后
            // 才被布局；在这里重试，直到拿到自己的祖先滚动视图。
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
            observation = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: clipView,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.reevaluate()
                }
            }
            // 登记到接力表：内层到底时把剩余增量转给外层列表。
            ProcessSectionScrollRelay.shared.register(scrollView)
            reevaluate()
        }

        fileprivate func stopObserving() {
            if let observation {
                NotificationCenter.default.removeObserver(observation)
                self.observation = nil
            }
            if let observedScrollView {
                ProcessSectionScrollRelay.shared.unregister(observedScrollView)
            }
            observedScrollView = nil
            hasEvaluatedOnce = false
            lastAtBottom = true
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

            let isFirstEvaluation = !hasEvaluatedOnce
            hasEvaluatedOnce = true

            if atBottom != lastAtBottom {
                lastAtBottom = atBottom
                onAtBottomChange?(atBottom)
            }
            // 只有「非首次」评估中离开底部，才是用户主动上滚。
            // 首次评估时折叠区可能本来就在顶部（内容超长），那不是用户行为。
            if !atBottom && !isFirstEvaluation {
                onUserScrolledAway?()
            }
        }
    }
}
