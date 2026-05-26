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

        if let fileURL, isHTMLInSyncWithFile(at: fileURL) {
            let readAccessURL = fileURL.deletingLastPathComponent()
            webView.loadFileURL(fileURL, allowingReadAccessTo: readAccessURL)
        } else if let fileURL {
            let baseURL = fileURL.deletingLastPathComponent().absoluteDirectoryURL
            webView.loadHTMLString(html, baseURL: baseURL)
        } else {
            webView.loadHTMLString(html, baseURL: nil)
        }
    }

    private func isHTMLInSyncWithFile(at url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url),
              let fileText = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) else {
            return false
        }
        return fileText == html
    }

    fileprivate final class Coordinator {
        var lastLoadKey: LoadKey?
    }

    fileprivate struct LoadKey: Equatable {
        let html: String
        let fileURL: URL?
    }
}

private extension URL {
    var absoluteDirectoryURL: URL {
        var absoluteString = absoluteString
        if !absoluteString.hasSuffix("/") {
            absoluteString += "/"
        }
        return URL(string: absoluteString) ?? self
    }
}
