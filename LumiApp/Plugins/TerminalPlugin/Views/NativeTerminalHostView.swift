import SwiftUI
import Foundation
import SwiftTerm

struct NativeTerminalHostView: NSViewRepresentable {
    @ObservedObject var session: TerminalSession

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        // SwiftTerm 终端会话是长生命周期对象，直接复用对应的 NSView。
        session.terminalView
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {}
}
