import SwiftUI
import Foundation
import SwiftTerm

struct NativeTerminalHostView: NSViewRepresentable {
    @ObservedObject var session: TerminalSession

    func makeNSView(context: Context) -> LumiTerminalView {
        // SwiftTerm 终端会话是长生命周期对象，直接复用对应的 NSView。
        session.terminalView
    }

    func updateNSView(_ nsView: LumiTerminalView, context: Context) {
        // 颜色更新由 TerminalSession 通过 applyThemeColors() 驱动，此处无需额外处理
    }

    static func dismantleNSView(_ nsView: LumiTerminalView, coordinator: ()) {
        // 当 SwiftUI 从视图层级中移除终端视图时，不要销毁它
        // 只需要将其从 superview 中移除，保持内部状态完整
        nsView.removeFromSuperview()
    }
}
