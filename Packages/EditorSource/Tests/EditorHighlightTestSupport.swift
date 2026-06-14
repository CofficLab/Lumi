import AppKit
import EditorLanguageRuntime
import EditorTextView
import XCTest
@testable import EditorSource

enum EditorHighlightTestSupport {
    @MainActor
    static func makeTextViewInScrollView(text: String) -> TextView {
        let textView = TextView(
            string: text,
            font: .monospacedSystemFont(ofSize: 12, weight: .regular),
            wrapLines: false
        )
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 480, height: 320))
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.documentView = textView
        textView.frame = NSRect(x: 0, y: 0, width: 480, height: 320)
        textView.layoutManager.layoutLines()
        return textView
    }
}
