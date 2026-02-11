import SwiftUI
import AppKit

struct ConsoleTextView: NSViewRepresentable {
    @Binding var text: NSAttributedString
    var onInput: (Data) -> Void
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        
        let textView = TerminalNSTextView()
        textView.isEditable = false // We handle input manually
        textView.isSelectable = true
        textView.backgroundColor = .black
        textView.textColor = .white
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.delegate = context.coordinator
        
        // Connect input handler
        textView.onInput = onInput
        
        // Layout
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        
        scrollView.documentView = textView
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? TerminalNSTextView else { return }
        
        // Update handler just in case
        textView.onInput = onInput
        
        if textView.textStorage?.string != text.string {
            textView.textStorage?.setAttributedString(text)
            textView.scrollToEndOfDocument(nil)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ConsoleTextView
        
        init(_ parent: ConsoleTextView) {
            self.parent = parent
        }
    }
}

class TerminalNSTextView: NSTextView {
    var onInput: ((Data) -> Void)?
    
    // Override keyDown to capture input
    override func keyDown(with event: NSEvent) {
        guard let chars = event.characters else { return }

        // Handle special keys
        if event.specialKey != nil {
            // Arrow keys, etc.
            // Need to map to ANSI sequences (e.g. Up -> ESC [ A)
            // For MVP, just handle basic text
        }
        
        // Enter key
        if event.keyCode == 36 {
            sendData(Data([0x0D])) // CR
            return
        }
        
        // Backspace (127)
        if event.keyCode == 51 {
            sendData(Data([0x7F]))
            return
        }
        
        // Ctrl+C (ETX)
        if event.modifierFlags.contains(.control) {
            if chars == "c" {
                sendData(Data([0x03]))
                return
            }
            if chars == "d" {
                sendData(Data([0x04])) // EOT
                return
            }
        }
        
        if let data = chars.data(using: .utf8) {
            sendData(data)
        }
    }
    
    private func sendData(_ data: Data) {
        // We need a way to pass this back up.
        // Since NSViewRepresentable creates this, we can't easily bind a closure directly 
        // unless we assign it in updateNSView or via coordinator.
        // But for simplicity, let's look up the coordinator? 
        // Actually, the best way is to have the Coordinator assign itself as delegate,
        // but keyDown is an override.
        
        // Quick hack: Use Notification or just rely on parent context if we could access it.
        // Let's use a closure property that the Coordinator sets.
        onInput?(data)
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .inRootView()
        .withDebugBar()
}
