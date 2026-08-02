import LumiUI
import SwiftUI

/// Renders a decoded HTTP payload (headers, body, options) as a scrollable
/// monospaced code block. Loaded lazily on `.task(id:)` to avoid blocking the
/// main thread for large bodies.
struct HTTPExchangePayloadView: View {
    @LumiTheme private var theme

    let data: Data?
    let fallback: String

    @State private var renderedText: String?

    var body: some View {
        Group {
            if let renderedText {
                codeBlock(renderedText)
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading payload…")
                        .font(.appCaption)
                        .foregroundStyle(theme.textSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
            }
        }
        .task(id: data) {
            await renderPayload()
        }
    }

    private func renderPayload() async {
        guard let data else {
            renderedText = fallback
            return
        }

        let rendered = await Task.detached(priority: .utility) {
            HTTPExchangeExportFormatter.text(data)
        }.value
        renderedText = rendered
    }

    private func codeBlock(_ text: String) -> some View {
        GeometryReader { proxy in
            ScrollView([.horizontal, .vertical]) {
                Text(text)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(theme.textPrimary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: true, vertical: true)
                    .padding(10)
                    // A bidirectional ScrollView centers content that is
                    // narrower than its viewport unless its content has a
                    // viewport-sized minimum width.
                    .frame(minWidth: proxy.size.width, alignment: .leading)
            }
        }
        .frame(minHeight: 70, maxHeight: 260)
        .background(theme.textSecondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
