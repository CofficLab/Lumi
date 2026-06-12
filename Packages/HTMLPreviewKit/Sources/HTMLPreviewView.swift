import SwiftUI
import WebKit

/// HTML 文件预览视图。
///
/// 使用 WKWebView 实时渲染 HTML 内容。
/// 可通过 `fileURL` 直接加载本地文件（支持相对资源引用），
/// 或通过 `htmlText` 加载纯 HTML 字符串。
public struct HTMLPreviewView: View {

    let htmlText: String
    let fileURL: URL?
    var onWebViewResolved: ((WKWebView) -> Void)?

    public init(
        htmlText: String,
        fileURL: URL? = nil,
        onWebViewResolved: ((WKWebView) -> Void)? = nil
    ) {
        self.htmlText = htmlText
        self.fileURL = fileURL
        self.onWebViewResolved = onWebViewResolved
    }

    public var body: some View {
        Group {
            if htmlText.isEmpty {
                emptyView
            } else {
                GeometryReader { geometry in
                    _WKWebViewWrapper(
                        html: htmlText,
                        fileURL: fileURL,
                        containerSize: geometry.size,
                        onWebViewResolved: onWebViewResolved
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 10) {
            Image(systemName: "globe")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("No HTML content to preview.", comment: "Empty state when there is no HTML to render")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
        .padding(24)
    }
}

// MARK: - WKWebView Wrapper

private struct _WKWebViewWrapper: NSViewRepresentable {
    let html: String
    let fileURL: URL?
    let containerSize: CGSize
    let onWebViewResolved: ((WKWebView) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: CGRect(origin: .zero, size: containerSize), configuration: config)
        webView.allowsMagnification = true
        webView.translatesAutoresizingMaskIntoConstraints = false
        DispatchQueue.main.async {
            onWebViewResolved?(webView)
        }
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        DispatchQueue.main.async {
            onWebViewResolved?(webView)
        }

        if webView.frame.size != containerSize {
            webView.frame = CGRect(origin: .zero, size: containerSize)
        }

        let loadKey = LoadKey(html: html, fileURL: fileURL)
        guard context.coordinator.lastLoadKey != loadKey else { return }
        context.coordinator.lastLoadKey = loadKey

        switch HTMLPreviewLoadPlanner().loadRequest(html: html, fileURL: fileURL) {
        case .file(let fileURL, let readAccessURL):
            webView.loadFileURL(fileURL, allowingReadAccessTo: readAccessURL)
        case .html(let html, let baseURL):
            webView.loadHTMLString(html, baseURL: baseURL)
        }
    }

    fileprivate final class Coordinator {
        var lastLoadKey: LoadKey?
    }

    fileprivate struct LoadKey: Equatable {
        let html: String
        let fileURL: URL?
    }
}
