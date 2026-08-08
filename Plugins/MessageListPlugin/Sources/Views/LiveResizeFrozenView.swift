import AppKit
import SwiftUI

/// 在 macOS live-resize 期间冻结 SwiftUI 内容。
///
/// 拖动开始时把当前可见内容缓存为位图,然后隐藏真实的
/// `NSHostingView`。拖动期间只缩放这张位图,不向宿主传递中间宽度,
/// 因此 Markdown 和消息行不会每帧重新 layout。松手后才把最终尺寸和
/// 期间积累的最新 root view 一次性交给宿主。
struct LiveResizeFrozenView<Content: View>: NSViewRepresentable {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeNSView(context: Context) -> LiveResizeFrozenContainer<Content> {
        LiveResizeFrozenContainer(rootView: content)
    }

    func updateNSView(_ nsView: LiveResizeFrozenContainer<Content>, context: Context) {
        nsView.updateRootView(content)
    }
}

@MainActor
final class LiveResizeFrozenContainer<Content: View>: NSView {
    private let hostingView: NSHostingView<Content>
    private let frozenLayer = CALayer()
    private var pendingRootView: Content?
    private var isFrozen = false

    init(rootView: Content) {
        hostingView = NSHostingView(rootView: rootView)
        super.init(frame: .zero)

        autoresizesSubviews = false
        wantsLayer = true
        layer?.masksToBounds = true
        layerContentsRedrawPolicy = .duringViewResize
        frozenLayer.contentsGravity = .resize
        frozenLayer.masksToBounds = true
        frozenLayer.isHidden = true
        layer?.addSublayer(frozenLayer)
        addSubview(hostingView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }

    override func layout() {
        super.layout()
        if isFrozen {
            // Keep the cached frame in the compositor while the container
            // follows the window's live-resize bounds. The hosting view is
            // deliberately not laid out until live resize ends.
            frozenLayer.frame = bounds
            return
        }
        hostingView.frame = bounds
    }

    func updateRootView(_ rootView: Content) {
        if isFrozen || window?.inLiveResize == true {
            pendingRootView = rootView
        } else {
            hostingView.rootView = rootView
        }
    }

    override func viewWillStartLiveResize() {
        super.viewWillStartLiveResize()
        freezeCurrentFrame()
    }

    override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        restoreHostedContent()
    }

    private func freezeCurrentFrame() {
        guard !isFrozen, !bounds.isEmpty else { return }

        hostingView.layoutSubtreeIfNeeded()
        guard let bitmap = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            return
        }
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)

        // Put the snapshot directly in a compositor layer. This avoids
        // asking AppKit to invoke draw(_:) for every intermediate resize
        // rect; during live resize only the layer's bounds change.
        frozenLayer.contents = bitmap.cgImage
        frozenLayer.frame = bounds
        frozenLayer.isHidden = false
        isFrozen = true
        hostingView.isHidden = true
    }

    private func restoreHostedContent() {
        guard isFrozen else { return }

        if let pendingRootView {
            hostingView.rootView = pendingRootView
            self.pendingRootView = nil
        }
        hostingView.frame = bounds
        hostingView.isHidden = false
        isFrozen = false
        frozenLayer.isHidden = true
        frozenLayer.contents = nil
        needsLayout = true
    }
}
