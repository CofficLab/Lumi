import SwiftTerm
import SwiftUI

/// 终端会话容器视图
///
/// 包装单个终端会话的 NSView，提供 SwiftUI 集成。
public struct TerminalSessionContainerView: View {
    @ObservedObject public var session: TerminalSession

    public init(session: TerminalSession) {
        self.session = session
    }

    public var body: some View {
        NativeTerminalHostView(session: session)
            .padding(10)
            .background(Color(nsColor: session.terminalView.nativeBackgroundColor))
    }
}

/// 原生终端宿主视图
///
/// 将 SwiftTerm 的 NSView 包装为 SwiftUI View。
public struct NativeTerminalHostView: NSViewRepresentable {
    @ObservedObject public var session: TerminalSession

    public init(session: TerminalSession) {
        self.session = session
    }

    public func makeNSView(context: Context) -> LumiTerminalView {
        // SwiftTerm 终端会话是长生命周期对象，直接复用对应的 NSView。
        session.terminalView
    }

    public func updateNSView(_ nsView: LumiTerminalView, context: Context) {
        // 颜色更新由 TerminalSession 通过 applyThemeColors() 驱动，此处无需额外处理
    }

    public static func dismantleNSView(_ nsView: LumiTerminalView, coordinator: ()) {
        // 当 SwiftUI 从视图层级中移除终端视图时，不要销毁它
        // 只需要将其从 superview 中移除，保持内部状态完整
        nsView.removeFromSuperview()
    }
}