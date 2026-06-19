import AppKit
import SwiftUI

/// High-throughput read-only log viewer backed by `NSTextView`.
struct BuildLogTextView: NSViewRepresentable {
    let text: String
    var autoScrollToBottom: Bool = true
    var fontSize: CGFloat = 11

    final class Coordinator {
        var renderedLength = 0
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.textColor = .secondaryLabelColor
        textView.textContainerInset = NSSize(width: 12, height: 8)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        if text.isEmpty {
            if context.coordinator.renderedLength != 0 {
                textView.string = ""
                context.coordinator.renderedLength = 0
            }
            return
        }

        if context.coordinator.renderedLength == 0
            || text.count < context.coordinator.renderedLength
            || !text.hasPrefix(String(text.prefix(context.coordinator.renderedLength))) {
            textView.string = text
            context.coordinator.renderedLength = text.count
        } else if text.count > context.coordinator.renderedLength {
            let start = text.index(text.startIndex, offsetBy: context.coordinator.renderedLength)
            let delta = String(text[start...])
            textView.textStorage?.append(
                NSAttributedString(
                    string: delta,
                    attributes: [
                        .font: textView.font as Any,
                        .foregroundColor: NSColor.secondaryLabelColor,
                    ]
                )
            )
            context.coordinator.renderedLength = text.count
        }

        if autoScrollToBottom {
            textView.layoutManager?.ensureLayout(for: textView.textContainer!)
            let visibleRect = textView.visibleRect
            let bounds = textView.bounds
            let isNearBottom = visibleRect.maxY >= bounds.maxY - 48
            if isNearBottom {
                textView.scrollToEndOfDocument(nil)
            }
        }
    }
}
