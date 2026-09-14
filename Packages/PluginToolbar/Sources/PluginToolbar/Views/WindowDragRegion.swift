import SwiftUI

#if os(macOS)
import AppKit

/// 整条工具栏的窗口拖拽区：与旧版 `AppTitleToolbar` 的拖拽行为一致。
internal struct WindowDragRegion: NSViewRepresentable {
    func makeNSView(context: Context) -> DragRegionView {
        DragRegionView()
    }

    func updateNSView(_ nsView: DragRegionView, context: Context) {}
}

/// `mouseDownCanMoveWindow` 置为 true 后，点击工具栏空白处即可拖动窗口。
internal final class DragRegionView: NSView {
    override var mouseDownCanMoveWindow: Bool {
        true
    }
}
#endif
