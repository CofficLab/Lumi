import os
import SwiftUI
import WebKit

/// HTML 文件预览视图。
///
/// 使用 WKWebView 实时渲染 HTML 内容。
struct EditorPreviewHTMLView: View, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.editor-inline-preview.html-view"
    )
    nonisolated static let emoji = "🌐"
    nonisolated static let verbose: Bool = true

    @EnvironmentObject private var themeVM: AppThemeVM

    let htmlText: String
    let fileURL: URL?

    var body: some View {
        Group {
            if htmlText.isEmpty {
                emptyView
            } else {
                GeometryReader { geometry in
                    WKWebViewWrapper(
                        html: htmlText,
                        fileURL: fileURL,
                        containerSize: geometry.size
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeVM.activeChromeTheme.workspaceBackgroundColor())
    }

    private var emptyView: some View {
        VStack(spacing: 10) {
            Image(systemName: "globe")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text(String(localized: "No HTML content to preview.", table: "EditorPreview"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
        .padding(24)
    }
}

// MARK: - WKWebView Wrapper

private struct WKWebViewWrapper: NSViewRepresentable {
    let html: String
    let fileURL: URL?
    let containerSize: CGSize

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: CGRect(origin: .zero, size: containerSize), configuration: config)
        webView.allowsMagnification = true
        webView.translatesAutoresizingMaskIntoConstraints = false
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // 更新 frame 以匹配容器尺寸
        if webView.frame.size != containerSize {
            webView.frame = CGRect(origin: .zero, size: containerSize)
        }

        // 加载内容
        if let fileURL {
            let baseURL = fileURL.deletingLastPathComponent()
            webView.loadHTMLString(html, baseURL: baseURL)
        } else {
            webView.loadHTMLString(html, baseURL: nil)
        }
    }

    static func dismantleNSView(_ nsView: WKWebView, coordinator: ()) {
        // 清理
    }
}