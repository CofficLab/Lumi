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
        .frame(minHeight: 100, maxHeight: 360)
        .background(theme.textSecondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
