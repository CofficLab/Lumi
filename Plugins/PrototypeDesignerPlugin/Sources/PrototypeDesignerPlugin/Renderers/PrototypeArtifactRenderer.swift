import SwiftUI
import WebKit
import KernelLumi

/// 贡献的消息渲染器：把含 `<artifact>` 的工具结果消息，渲染成内嵌的 WKWebView 交互预览。
///
/// order 设为 400，高于内置 `core-tool-message`（250），从而抢占对「原型工具结果」的匹配；
/// 其它普通 `.tool` 消息仍由内置渲染器处理。
enum PrototypeArtifactRenderer {
    static let item = LumiMessageRendererItem(
        id: "prototype-designer.artifact",
        order: 400,
        canRender: { message in
            // 仅匹配「能解析出 artifact」的工具结果消息。
            message.role == .tool && ArtifactExtractor.extract(from: message.content) != nil
        },
        render: { message, _ in
            PrototypeArtifactMessageView(message: message)
        }
    )
}

// MARK: - 渲染视图

private struct PrototypeArtifactMessageView: View {
    let message: LumiChatMessage

    var body: some View {
        if let artifact = ArtifactExtractor.extract(from: message.content) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "wand.and.stars")
                        .foregroundStyle(.tint)
                    Text(artifact.title)
                        .font(.headline)
                    Spacer()
                    Label(artifact.device.displayName, systemImage: artifact.device.systemImage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .labelStyle(.titleAndIcon)
                }

                PrototypeHTMLPreview(html: artifact.html)
                    .frame(height: 360)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )

                if !supplementaryText.isEmpty {
                    Text(supplementaryText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } else {
            Text(message.content)
                .font(.subheadline)
        }
    }

    /// artifact 标签之外的文字说明（去掉 HTML 后剩余部分）。
    private var supplementaryText: String {
        let pattern = #"<artifact[^>]*>[\s\S]*?</artifact>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return message.content
        }
        let ns = message.content as NSString
        let stripped = regex.stringByReplacingMatches(
            in: message.content,
            options: [],
            range: NSRange(location: 0, length: ns.length),
            withTemplate: ""
        )
        return stripped.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - WKWebView 桥接

/// 用 WKWebView 渲染单文件 HTML。
private struct PrototypeHTMLPreview: NSViewRepresentable {
    let html: String

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        load(into: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        load(into: webView)
    }

    private func load(into webView: WKWebView) {
        webView.loadHTMLString(html, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    /// 阻止原型内的链接把预览区导航走：所有 linkActivated 都忽略，保持预览稳定。
    final class Coordinator: NSObject, WKNavigationDelegate {
        @MainActor
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction
        ) async -> WKNavigationActionPolicy {
            navigationAction.navigationType == .linkActivated ? .cancel : .allow
        }
    }
}
