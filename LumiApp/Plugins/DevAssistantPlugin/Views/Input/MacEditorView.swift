import AppKit
import SwiftUI

/// Mac 编辑器视图
/// 基于 NSTextView 的自定义编辑器，支持快捷键、拖放和焦点管理
struct MacEditorView: NSViewRepresentable {
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
    /// 文件拖放回调：处理拖放的文件 URL
    var onDrop: (([URL]) -> Bool)? = nil

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let textView = EditorTextView()
        textView.onDrop = onDrop
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
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainerInset = NSSize(width: 4, height: 4) // 添加一点内边距以匹配 TextEditor

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? EditorTextView else { return }

        textView.onDrop = onDrop

        if textView.string != text {
            textView.string = text
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

    /// 协调器：处理文本变化和按键事件
    class Coordinator: NSObject, NSTextViewDelegate {
        /// 父视图引用
        var parent: MacEditorView

        init(_ parent: MacEditorView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                if let onEnter = parent.onEnter {
                    onEnter()
                    return true
                }
                if let event = NSApp.currentEvent, event.modifierFlags.contains(.shift) {
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

/// 编辑器文本视图
/// 扩展 NSTextView 以支持文件拖放功能
class EditorTextView: NSTextView {
    /// 文件拖放回调
    var onDrop: (([URL]) -> Bool)?

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard

        // 检查文件 URL
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty {
            if let onDrop = onDrop, onDrop(urls) {
                return true
            }
        }

        return super.performDragOperation(sender)
    }
}

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .withNavigation(DevAssistantPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
