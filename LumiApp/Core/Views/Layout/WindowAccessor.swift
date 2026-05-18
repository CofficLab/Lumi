import AppKit
import SwiftUI

/// 轻量 NSViewRepresentable，用于可靠获取当前 SwiftUI view 所在的 NSWindow。
///
/// 在多窗口场景下，`NSApplication.shared.keyWindow` 可能指向其他窗口，
/// 使用 `WindowAccessor` 可以精确绑定当前 view 与其所属窗口。
struct WindowAccessor: NSViewRepresentable {
    /// 当成功获取到 NSWindow 时回调
    let onResolve: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                onResolve(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                onResolve(window)
            }
        }
    }
}
