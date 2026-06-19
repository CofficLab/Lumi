import AppKit
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
    /// When set, the WebView renders at this logical size and scales down to fit the container.
    let contentSize: CGSize?
    var onWebViewResolved: ((WKWebView) -> Void)?

    public init(
        htmlText: String,
        fileURL: URL? = nil,
        contentSize: CGSize? = nil,
        onWebViewResolved: ((WKWebView) -> Void)? = nil
    ) {
        self.htmlText = htmlText
        self.fileURL = fileURL
        self.contentSize = contentSize
        self.onWebViewResolved = onWebViewResolved
    }

    public var body: some View {
        Group {
            if htmlText.isEmpty {
                emptyView
            } else if contentSize != nil {
                ZStack {
                    Color(nsColor: .windowBackgroundColor)
                    PreviewBoardGrid()
                    previewContent
                }
            } else {
                previewContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var previewContent: some View {
        GeometryReader { geometry in
            let webViewSize = contentSize ?? geometry.size
            let fitScale = Self.fitScale(contentSize: contentSize, in: geometry.size)

            _WKWebViewWrapper(
                html: htmlText,
                fileURL: fileURL,
                containerSize: webViewSize,
                onWebViewResolved: onWebViewResolved
            )
            .frame(width: webViewSize.width, height: webViewSize.height)
            .scaleEffect(fitScale)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private static func fitScale(contentSize: CGSize?, in containerSize: CGSize) -> CGFloat {
        guard let contentSize,
              contentSize.width > 0,
              contentSize.height > 0,
              containerSize.width > 0,
              containerSize.height > 0 else {
            return 1
        }
        return min(containerSize.width / contentSize.width, containerSize.height / contentSize.height)
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
