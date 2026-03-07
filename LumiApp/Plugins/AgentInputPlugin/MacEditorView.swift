import AppKit
import MagicKit
import OSLog
import SwiftUI

/// Mac 编辑器视图
/// 基于 NSTextView 的自定义编辑器，支持快捷键、拖放和焦点管理
struct MacEditorView: NSViewRepresentable, SuperLog {
    /// 日志标识 emoji
    nonisolated static let emoji = "✏️"
    /// 是否输出详细日志
    nonisolated static let verbose = true

    /// 绑定的文本内容
    @Binding var text: String

    /// 字体设置
    var font: NSFont = .systemFont(ofSize: 15)

    /// 提交回调：当用户按下 Enter 键时触发
    var onSubmit: () -> Void

    /// 上箭头键回调：用于命令建议列表的上移选择
    var onArrowUp: (() -> Void)? = nil

    /// 下箭头键回调：用于命令建议列表的下移选择
    var onArrowDown: (() -> Void)? = nil

    /// 回车键回调：用于触发命令建议或提交
    var onEnter: (() -> Void)? = nil

    /// 焦点状态绑定
    @Binding var isFocused: Bool

    /// 光标位置绑定
    @Binding var cursorPosition: Int

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let textView = EditorTextView()
        textView.autoresizingMask = [.width]
        textView.delegate = context.coordinator
        textView.drawsBackground = false
        textView.font = font
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.allowsUndo = true

        // 设置文本容器
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainerInset = NSSize(width: 4, height: 4)

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? EditorTextView else { return }

        // 如果用户正在使用输入法组合文字（存在 markedText），不要强制同步，否则会打断输入状态
        if textView.hasMarkedText() {
            return
        }

        // 只有当文本真正不同步时才更新，避免不必要的布局循环
        let textChanged = textView.string != text
        if textChanged {
            // 临时移除 delegate 防止触发 textDidChange 造成循环更新
            textView.delegate = nil
            textView.string = text
            textView.delegate = context.coordinator
        }

        // 更新光标位置（延迟到下一个 runloop 确保文本已更新）
        let targetPosition = min(cursorPosition, text.count)
        if textView.selectedRange().location != targetPosition || textChanged {
            DispatchQueue.main.async {
                textView.setSelectedRange(NSRange(location: targetPosition, length: 0))
            }
        }

        if isFocused {
            DispatchQueue.main.async {
                if let window = nsView.window, window.firstResponder != textView {
                    window.makeFirstResponder(textView)
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
}

// MARK: - Coordinator

extension MacEditorView {
    /// 协调器：处理文本变化和按键事件
    class Coordinator: NSObject, NSTextViewDelegate {
        /// 父视图引用
        var parent: MacEditorView

        init(_ parent: MacEditorView) {
            self.parent = parent
        }

        /// 文本变化回调
        /// - Parameter notification: 通知对象
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            // 同步光标位置
            let location = textView.selectedRange().location
            if parent.cursorPosition != location {
                parent.cursorPosition = location
            }
        }

        /// 按键事件处理
        /// - Parameters:
        ///   - textView: 文本视图
        ///   - commandSelector: 命令选择器
        /// - Returns: 是否已处理该命令
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                if let onEnter = parent.onEnter {
                    onEnter()
                    return true
                }
                if let event = NSApp.currentEvent,
                   event.modifierFlags.contains(.shift)
                {
                    return false // 允许换行 (Shift + Enter)
                }
                parent.onSubmit()
                return true // 阻止换行并触发提交
            } else if commandSelector == #selector(NSResponder.moveUp(_:)) {
                if let onArrowUp = parent.onArrowUp {
                    onArrowUp()
                    return true
                }
            } else if commandSelector == #selector(NSResponder.moveDown(_:)) {
                if let onArrowDown = parent.onArrowDown {
                    onArrowDown()
                    return true
                }
            }
            return false
        }
    }
}

// MARK: - EditorTextView

/// 编辑器文本视图
/// 扩展 NSTextView 以支持文件拖放功能
class EditorTextView: NSTextView, SuperLog {
    /// 日志标识 emoji
    nonisolated static let emoji = "📝"
    /// 是否输出详细日志
    nonisolated static let verbose = false

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        
        if Self.verbose {
            os_log("\(Self.t)📎 performDragOperation 被调用")
        }

        // 首先尝试读取文件 URL
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           !urls.isEmpty
        {
            if Self.verbose {
                os_log("\(Self.t)📎 读取到 \(urls.count) 个 URL: \(urls.first?.path ?? "unknown")")
            }
            // 发送通知让 InputAreaView 处理
            NotificationCenter.postFileDroppedToChat(fileURL: urls.first!)
            return true
        }
        
        // 尝试读取纯文本（用于从项目树拖放的文件路径字符串）
        if let strings = pasteboard.readObjects(forClasses: [NSString.self], options: nil) as? [String],
           !strings.isEmpty,
           let firstString = strings.first
        {
            if Self.verbose {
                os_log("\(Self.t)📎 读取到字符串: \(firstString)")
            }
            // 如果是绝对路径，发送通知
            if firstString.hasPrefix("/") {
                NotificationCenter.postFileDroppedToChat(fileURL: URL(fileURLWithPath: firstString))
                return true
            }
        }
        
        if Self.verbose {
            os_log("\(Self.t)⚠️ 没有读取到有效的拖放数据")
        }

        return super.performDragOperation(sender)
    }
}

// MARK: - Preview

#Preview("Editor") {
    MacEditorView(
        text: .constant("Hello, World!"),
        onSubmit: {},
        onArrowUp: {},
        onArrowDown: {},
        onEnter: {},
        isFocused: .constant(true),
        cursorPosition: .constant(0)
    )
    .frame(height: 100)
    .padding()
    .background(Color.black)
    .inRootView()
}
