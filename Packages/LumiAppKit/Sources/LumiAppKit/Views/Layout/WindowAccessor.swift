import AppKit
import LumiUI
import SwiftUI

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

extension NSWindow {
    func configureForLumiMainChrome() {
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        toolbar = nil
        styleMask.insert(.fullSizeContentView)
        ThemeWindowAppearanceSync.syncAllWindows()
    }
}
