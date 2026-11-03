import AppKit
import SwiftUI

/// 过程折叠区的**滚动几何探针**（仅 DEBUG，供 UI 测试读取）。
///
/// ## 为什么需要它
///
/// 折叠区「滚不动」这个问题，**所有**外部观察都有歧义：
///
/// - AX 帧：未物化的行在列表坐标系里也有布局位置（实测 y≈3954），
///   拿它们当判据只会得到恒定的「没变化」；
/// - 合成滚轮事件：SwiftUI 的 `ScrollView` **不接受**任何投到窗口上的
///   合成事件（实测：原生 `NSScrollView` 接受、SwiftUI 的
///   `HostingScrollView` 一律 Δ=0，无论是否带 phase、无论投到
///   `.cghidEventTap` 还是 `.cgSessionEventTap`）。
///
/// 唯一无歧义的观测点是**内层滚动视图自己的几何**：
/// `clipView.bounds.origin.y`（当前偏移）、`documentView.bounds.height`
/// （内容高度）、`contentView.bounds.height`（视口高度）。
///
/// 因此这里把三个值编码成字符串，挂成一个**独立的隐藏 AX 元素**
/// 放在折叠区**内部**。
///
/// - Important: 不能直接给 `ScrollView` 加 `accessibilityValue` ——
///   那会让 SwiftUI 把折叠区整体变成一个 `AXScrollArea` 容器，
///   UI 测试随即报「Unable to find hit point for ScrollView」。
///   独立的子元素不改变滚动视图自身的 AX 语义。
/// - Important: 只在 DEBUG 下编译，且内容是纯诊断数字 —— 不泄露任何
///   用户数据。
#if DEBUG
/// 把滚动几何编码成 AX 可读的字符串。
enum ProcessSectionGeometryProbe {
    /// 编码格式：`offset/documentHeight/visibleHeight`。
    static func encode(
        offset: CGFloat,
        documentHeight: CGFloat,
        visibleHeight: CGFloat
    ) -> String {
        String(format: "%.1f/%.1f/%.1f", offset, documentHeight, visibleHeight)
    }

    /// 解析编码后的几何。格式不符时返回 `nil`。
    static func decode(
        _ raw: String
    ) -> (offset: CGFloat, documentHeight: CGFloat, visibleHeight: CGFloat)? {
        let parts = raw.split(separator: "/")
        guard parts.count == 3,
              let offset = Double(parts[0]),
              let document = Double(parts[1]),
              let visible = Double(parts[2]) else {
            return nil
        }
        return (offset, document, visible)
    }
}

/// 采集内层滚动视图几何的零尺寸视图。
///
/// - Important: 必须放在 `ScrollView` 的**内容内部**，否则
///   `enclosingScrollView` 恒为 `nil`（与
///   ``BoundedProcessSectionScrollObserver`` 同一个约束）。
struct ProcessSectionGeometryProbeView: NSViewRepresentable {
    /// 几何变化时回调（编码后的字符串）。
    let onChange: (String) -> Void

    init(onChange: @escaping (String) -> Void) {
        self.onChange = onChange
    }

    func makeNSView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.onChange = onChange
        return view
    }

    func updateNSView(_ nsView: ProbeView, context: Context) {
        nsView.onChange = onChange
    }

    static func dismantleNSView(_ nsView: ProbeView, coordinator: Coordinator) {
        nsView.stopObserving()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var onChange: (String) -> Void
        init(onChange: @escaping (String) -> Void = { _ in }) {
            self.onChange = onChange
        }
    }

    @MainActor
    final class ProbeView: NSView {
        fileprivate var onChange: ((String) -> Void)?
        private var observation: NSObjectProtocol?
        private weak var observedScrollView: NSScrollView?
        private var lastRaw = ""

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
            attachIfNeeded()
        }

        private func attachIfNeeded() {
            guard let scrollView = enclosingScrollView else {
                stopObserving()
                return
            }
            guard scrollView !== observedScrollView else { return }
            stopObserving()
            observedScrollView = scrollView
            let clip = scrollView.contentView
            clip.postsBoundsChangedNotifications = true
            observation = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: clip,
                queue: nil
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.report()
                }
            }
            report()
        }

        fileprivate func stopObserving() {
            if let observation {
                NotificationCenter.default.removeObserver(observation)
                self.observation = nil
            }
            observedScrollView = nil
            lastRaw = ""
        }

        private func report() {
            guard let scrollView = observedScrollView else { return }
            let raw = ProcessSectionGeometryProbe.encode(
                offset: scrollView.contentView.bounds.origin.y,
                documentHeight: scrollView.documentView?.bounds.height ?? 0,
                visibleHeight: scrollView.contentView.bounds.height
            )
            guard raw != lastRaw else { return }
            lastRaw = raw
            onChange?(raw)
        }
    }
}
#endif
