import LumiKernel
import LumiUI
import os
import SuperLogKit
import SwiftUI
import WebKit

/// DOC/DOCX 文件预览视图。
///
/// 使用 `textutil` 将 Word 文档转为 HTML，再通过 WKWebView 渲染，支持滚动和缩放。
/// 截图时使用 `HTMLScreenshotter` 直接截取 WKWebView 内容。
public struct EditorPreviewDOCView: View, SuperLog {
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.editor-inline-preview.doc-view"
    )
    public nonisolated static let emoji = ""
    public nonisolated static let verbose: Bool = true

    @EnvironmentObject private var themeVM: AppThemeVM

    public let fileURL: URL
    public var onWebViewResolved: ((WKWebView) -> Void)?

    public var body: some View {
        Group {
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                fileNotFoundView
            } else {
                DOCWebView(fileURL: fileURL, onWebViewResolved: onWebViewResolved)
            }
        }
        .background(themeVM.activeChromeTheme.workspaceBackgroundColor())
    }

    private var fileNotFoundView: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.badge.exclamationmark")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text(String(
                format: LumiPluginLocalization.string("File not found: %@", bundle: .module),
                fileURL.lastPathComponent
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
        .padding(24)
    }
}

// MARK: - DOC WebView

private struct DOCWebView: NSViewRepresentable {
    let fileURL: URL
    var onWebViewResolved: ((WKWebView) -> Void)?

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.autoresizingMask = [.width, .height]
        webView.setValue(false, forKey: "drawsBackground")
        DispatchQueue.main.async {
            onWebViewResolved?(webView)
        }
        loadContent(in: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        loadContent(in: webView)
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView: WKWebView,
        context: Context
    ) -> CGSize? {
        guard let width = proposal.width, let height = proposal.height else { return nil }
        return CGSize(width: width, height: height)
    }

    private func loadContent(in webView: WKWebView) {
        let url = webView.url?.standardizedFileURL
        let targetURL = fileURL.standardizedFileURL

        // 避免重复加载相同文件
        if url == targetURL, webView.isLoading == false {
            return
        }

        // 将 doc/docx 转为 HTML 临时文件后用 WKWebView 加载
        Task {
            do {
                let htmlURL = try await convertToHTML(fileURL)
                guard !Task.isCancelled else { return }
                let htmlData = try Data(contentsOf: htmlURL)
                let htmlString = String(data: htmlData, encoding: .utf8) ?? ""
                guard !Task.isCancelled else { return }

                // 清理临时文件
                try? FileManager.default.removeItem(at: htmlURL)

                guard !Task.isCancelled else { return }
                await MainActor.run {
                    webView.loadHTMLString(htmlString, baseURL: fileURL.deletingLastPathComponent())
                }
            } catch {
                await MainActor.run {
                    if EditorPreviewDOCView.verbose {
                        EditorPreviewDOCView.logger.error("\(EditorPreviewDOCView.t)📄 DOC 转换失败: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    /// 使用 textutil 将 doc/docx 转为 HTML
    private func convertToHTML(_ sourceURL: URL) async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let htmlFileName = "\(sourceURL.deletingPathExtension().lastPathComponent)_preview.html"
        let htmlURL = tempDir.appendingPathComponent(htmlFileName)

        // 如果已存在同名临时文件，先删除
        try? FileManager.default.removeItem(at: htmlURL)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/textutil")
        process.arguments = [
            "-convert", "html",
            "-output", htmlURL.path,
            sourceURL.path
        ]

        let pipe = Pipe()
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0,
              FileManager.default.fileExists(atPath: htmlURL.path) else {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorDesc = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "com.coffic.lumi.editor-preview.doc",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "textutil conversion failed: \(errorDesc)"]
            )
        }

        return htmlURL
    }
}
