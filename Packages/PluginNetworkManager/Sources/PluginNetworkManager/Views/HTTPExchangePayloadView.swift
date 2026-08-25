import AppKit
import LumiUI
import SwiftUI

/// Renders a decoded HTTP payload (headers, body, options) as a scrollable
/// monospaced code block. Loaded lazily on `.task(id:)` to avoid blocking the
/// main thread for large bodies.
struct HTTPExchangePayloadView: View {
    @LumiTheme private var theme

    let data: Data?
    let fallback: String
    /// When `true`, skips JSON pretty-printing and shows the original bytes
    /// as UTF-8 text (or hex dump). Defaults to `false`.
    var rawMode: Bool = false

    @State private var renderedText: String?

    var body: some View {
        Group {
            if let renderedText {
                codeBlock(renderedText)
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(LumiPluginLocalization.string("Loading payload…", bundle: .module))
                        .font(.appCaption)
                        .foregroundStyle(theme.textSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
            }
        }
        .task(id: "\(data?.count ?? 0)-\(rawMode)") {
            await renderPayload()
        }
    }

    private func renderPayload() async {
        guard let data else {
            renderedText = fallback
            return
        }

        let isRaw = rawMode
        let rendered = await Task.detached(priority: .utility) {
            if isRaw {
                HTTPExchangeExportFormatter.rawText(data)
            } else {
                HTTPExchangeExportFormatter.text(data)
            }
        }.value
        renderedText = rendered
    }

    private func codeBlock(_ text: String) -> some View {
        HTTPExchangeCodeTextView(text: text)
        .frame(minHeight: 100, maxHeight: 360)
        .background(theme.textSecondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

/// Native read-only code view used for payloads.
///
/// The detail page already lives inside a vertical ScrollView. A nested
/// SwiftUI bidirectional ScrollView can retain a scroll range while losing
/// the document view's measured size for large, unwrapped text. NSTextView
/// owns its document and scrolling independently, so long request bodies stay
/// visible and selectable without producing a blank scroll area.
private struct HTTPExchangeCodeTextView: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.drawsBackground = false
        textView.textColor = .labelColor
        textView.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.heightTracksTextView = false
        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.string = text

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        guard textView.string != text else { return }
        textView.string = text
        textView.scrollToBeginningOfDocument(nil)
    }
}
