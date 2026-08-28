import AppKit
import SwiftUI

/// 配置窗口 chrome：与旧版 Lumi（`WindowMain.configureForLumiMainChrome`）一致，
/// 内容延伸到标题栏区域（fullSizeContentView），红绿灯悬浮在工具栏上，
/// 保证顶部工具栏从窗口最顶部开始渲染、尺寸与旧版完全一致。
extension NSWindow {
    func configureForLumiMinimalChrome() {
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        toolbar = nil
        styleMask.insert(.fullSizeContentView)
    }
}

/// 解析宿主 NSWindow 并应用 chrome 配置的辅助视图。
struct WindowAccessor: NSViewRepresentable {
    let onResolve: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = HostView(onResolve: onResolve)
        view.resolveWindowIfAttached()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? HostView)?.resolveWindowIfAttached()
    }

    private final class HostView: NSView {
        let onResolve: (NSWindow) -> Void

        init(onResolve: @escaping (NSWindow) -> Void) {
            self.onResolve = onResolve
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            resolveWindowIfAttached()
        }

        func resolveWindowIfAttached() {
            guard let window else { return }
            onResolve(window)
        }
    }
}
