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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        session.startIfNeeded()
        DispatchQueue.main.async { [weak session] in
            session?.startIfNeeded()
        }
        return session.terminalView
    }

    public func updateNSView(_ nsView: LumiTerminalView, context: Context) {
        // 颜色更新由 TerminalSession 通过 applyThemeColors() 驱动，此处无需额外处理
        session.startIfNeeded()
    }

    public static func dismantleNSView(_ nsView: LumiTerminalView, coordinator: ()) {
        // 不要在这里 removeFromSuperview()：
        // 终端 NSView 是会话级共享对象，SwiftUI 重建宿主时旧的 representable
        // 才触发 dismantle，此时 NSView 可能已被挂到新的宿主上，
        // removeFromSuperview() 会把它从活跃宿主里拔掉，导致黑屏。
        // AppKit 的 addSubview 会自动处理 re-parent，无需手动移除。
    }
}
