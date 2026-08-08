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
    private var pendingRootView: Content?
    private var frozenImage: NSImage?
    private var isFrozen = false

    init(rootView: Content) {
        hostingView = NSHostingView(rootView: rootView)
        super.init(frame: .zero)

        autoresizesSubviews = false
        wantsLayer = true
        layer?.masksToBounds = true
        layerContentsRedrawPolicy = .duringViewResize
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
        guard !isFrozen else { return }
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

    override func draw(_ dirtyRect: NSRect) {
        guard let frozenImage else {
            super.draw(dirtyRect)
            return
        }

        NSGraphicsContext.current?.imageInterpolation = .high
        frozenImage.draw(
            in: bounds,
            from: NSRect(origin: .zero, size: frozenImage.size),
            operation: .copy,
            fraction: 1
        )
    }

    private func freezeCurrentFrame() {
        guard !isFrozen, !bounds.isEmpty else { return }

        hostingView.layoutSubtreeIfNeeded()
        guard let bitmap = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            return
        }
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)

        let image = NSImage(size: hostingView.bounds.size)
        image.addRepresentation(bitmap)
        frozenImage = image
        isFrozen = true
        hostingView.isHidden = true
        needsDisplay = true
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
        frozenImage = nil
        needsLayout = true
        needsDisplay = true
    }
}
