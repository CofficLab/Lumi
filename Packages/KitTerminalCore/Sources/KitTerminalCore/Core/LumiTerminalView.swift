import AppKit
import SwiftTerm

/// 自定义终端视图，保留 SwiftTerm 的完整 AppKit frame 生命周期。
public class LumiTerminalView: LocalProcessTerminalView {
    // MARK: - Ready 通知

    /// 视图首次挂到窗口并获得有效尺寸时触发（用于启动 shell）。
    ///
    /// SwiftUI 的 `makeNSView` / `updateNSView` 被调用时 frame 通常仍是 zero，
    /// 真正完成布局发生在之后，因此需要一个布局驱动的回调来启动 shell。
    public var onReady: (() -> Void)?

    private var didNotifyReady = false

    override public func layout() {
        super.layout()
        notifyReadyIfNeeded()
    }

    override public func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        notifyReadyIfNeeded()
    }

    private func notifyReadyIfNeeded() {
        guard !didNotifyReady,
              window != nil,
              bounds.width > 0,
              bounds.height > 0 else { return }
        didNotifyReady = true
        onReady?()
    }

    // MARK: - Process cleanup

    /// SwiftTerm 1.20.0 的自然退出路径不关闭 PTY master 的 DispatchIO（#175）：
    /// `LocalProcess.processTerminated()` 只 waitpid 回收子进程，EOF 路径只把
    /// childfd 置 -1。会话若因进程退出而结束（终端 Tab 仍在），master fd 永久
    /// 泄漏。这里在委托转发后补一次 terminate()：进程已死，SIGTERM 落在已回收
    /// 的 pid 上无害，io.close() 则触发 cleanup handler 释放 master fd。
    /// Tab 关闭路径不经过这里——terminate() 先取消了 childMonitor。
    override public func processTerminated(_ source: LocalProcess, exitCode: Int32?) {
        super.processTerminated(source, exitCode: exitCode)
        process?.terminate()
    }

    // MARK: - Accessibility

    override public func isAccessibilityElement() -> Bool {
        true
    }

    override public func isAccessibilityEnabled() -> Bool {
        true
    }

    override public func accessibilityLabel() -> String? {
        "Terminal Emulator"
    }

    override public func accessibilityRole() -> NSAccessibility.Role? {
        .textArea
    }

    override public func accessibilityValue() -> Any? {
        let terminal = getTerminal()
        // 只取可见视口：从 row 0 开始会把整段 scrollback 连同视口一起重建，
        // 每次无障碍查询的代价都与缓冲区总行数成正比（#1233）。
        let top = terminal.getTopVisibleRow()
        return terminal.getText(
            start: Position(col: 0, row: top),
            end: Position(col: terminal.cols, row: top + terminal.rows)
        )
    }
}
