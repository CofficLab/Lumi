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
        terminal.getText(
            start: Position(col: 0, row: 0),
            end: Position(col: terminal.cols, row: terminal.getTopVisibleRow() + terminal.rows)
        )
    }
}
