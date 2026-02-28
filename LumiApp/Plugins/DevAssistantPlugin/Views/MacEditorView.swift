import AppKit
import SwiftUI

struct MacEditorView: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont = .systemFont(ofSize: 15)
    var onSubmit: () -> Void
    var onArrowUp: (() -> Void)? = nil
    var onArrowDown: (() -> Void)? = nil
    var onEnter: (() -> Void)? = nil
    @Binding var isFocused: Bool
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

    class Coordinator: NSObject, NSTextViewDelegate {
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

class EditorTextView: NSTextView {
    var onDrop: (([URL]) -> Bool)?
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        
        // Check for file URLs
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
