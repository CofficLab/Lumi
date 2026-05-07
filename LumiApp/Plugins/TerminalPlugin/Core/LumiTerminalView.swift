import AppKit
import SwiftTerm

/// 自定义终端视图
///
/// 继承 `LocalProcessTerminalView` 并重写 frame 相关方法，
/// 防止 SwiftUI 在布局时传入 zero size 导致终端缓冲区被清空。
///
/// 问题原因：SwiftUI 在 Tab 切换、窗口 resize 或视图层级变化时，
/// 可能短暂给 NSView 传入 size 为 zero 的 frame。
/// SwiftTerm 的 `LocalProcessTerminalView` 收到 zero frame 时会重置终端，
/// 导致内容丢失。
class LumiTerminalView: LocalProcessTerminalView {
    override func setFrameSize(_ newSize: NSSize) {
        // 忽略 zero size，防止终端缓冲区被清空
        if newSize.width > 0 && newSize.height > 0 {
            super.setFrameSize(newSize)
        }
    }

    override var frame: CGRect {
        get {
            super.frame
        }
        set {
            // 忽略 zero size
            if newValue.width > 0 && newValue.height > 0 {
                super.frame = newValue
            }
        }
    }

    // MARK: - Accessibility

    override func isAccessibilityElement() -> Bool {
        true
    }

    override func isAccessibilityEnabled() -> Bool {
        true
    }

    override func accessibilityLabel() -> String? {
        "Terminal Emulator"
    }

    override func accessibilityRole() -> NSAccessibility.Role? {
        .textArea
    }

    override func accessibilityValue() -> Any? {
        terminal.getText(
            start: Position(col: 0, row: 0),
            end: Position(col: terminal.cols, row: terminal.getTopVisibleRow() + terminal.rows)
        )
    }
}
