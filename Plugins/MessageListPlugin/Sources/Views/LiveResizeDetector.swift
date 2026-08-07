import AppKit
import SwiftUI

/// Live-Resize Detector
///
/// 监听宿主 window 的 `willStartLiveResize` / `didEndLiveResize` 通知,通过
/// `Binding<Bool>` 把状态同步给宿主 SwiftUI 视图。
///
/// ## 用途
///
/// 宿主视图据此在 live-resize 期间把昂贵的富文本子树换成轻量占位行,
/// 使 SwiftUI 在 resize 的每一帧不再遍历富文本 layout —— 这是拖窗口宽度
/// 卡顿的根因(富文本子树的 layout 遍历开销,与宽度是否变化无关)。
///
/// 与早期「快照 overlay」「钉宽度」方案的区别:那些方案富文本子树始终留在
/// view tree 里,SwiftUI 每帧仍要遍历它;本方案在 resize 期间用 SwiftUI
/// 条件渲染**移除**富文本子树,SwiftUI 无昂贵子树可遍历。
///
/// ## 关于 state 翻转
///
/// 翻转 binding 会触发宿主 body 重建一次。这是**有意为之且可接受**的:
/// 重建发生在 resize 开始/结束两个瞬间,各一次;重建后 LazyVStack 内容已是
/// 轻量占位(或恢复富文本),后续 resize 帧不再有富文本遍历开销。
struct LiveResizeDetector: NSViewRepresentable {
    @Binding var isLiveResizing: Bool

    func makeNSView(context: Context) -> LiveResizeDetectorView {
        LiveResizeDetectorView(isLiveResizing: $isLiveResizing)
    }

    func updateNSView(_ nsView: LiveResizeDetectorView, context: Context) {
        nsView.isLiveResizingBinding = $isLiveResizing
    }
}

/// 监听 live-resize 的 backing NSView。零尺寸、不绘制、不参与命中测试。
///
/// 注意:本应用的 NSWindow 子类(AppKitWindow)不发送标准的
/// willStartLiveResize/didEndLiveResizeNotification,但 NSResponder 的
/// `viewWillStartLiveResize()` / `viewDidEndLiveResize()` 方法在视图链上正常触发。
/// 因此重写这两个方法来检测 resize 始末,比通知更可靠。
final class LiveResizeDetectorView: NSView {
    var isLiveResizingBinding: Binding<Bool>

    init(isLiveResizing: Binding<Bool>) {
        self.isLiveResizingBinding = isLiveResizing
        super.init(frame: .zero)
        wantsLayer = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Live-resize 检测(NSResponder 方法,不依赖通知)

    override func viewWillStartLiveResize() {
        super.viewWillStartLiveResize()
        isLiveResizingBinding.wrappedValue = true
    }

    override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        isLiveResizingBinding.wrappedValue = false
    }

    /// 不参与命中测试,零尺寸不绘制。
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
