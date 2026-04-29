import Foundation
import AppKit
import MagicKit
import WebKit

/// 网页截图工具
///
/// 使用 WKWebView 渲染指定 URL 的网页，等待页面加载完成后截取完整截图。
/// 截图保存到系统临时目录，返回文件路径。
struct BrowserScreenshotTool: AgentTool, SuperLog {
    nonisolated static let emoji = "📸"
    nonisolated static let verbose: Bool = false

    let name = "browser_screenshot"
    let description = """
Take a screenshot of a rendered web page. Uses WKWebView to load and render the page, then captures a full-page screenshot saved to a temporary file.

Use this tool when you need to visually inspect a web page or when text-based fetching (web_fetch) is insufficient (e.g., JavaScript-heavy pages, SPAs, pages that require login cookies).

Returns the file path of the saved screenshot image (PNG format).
"""

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "url": [
                    "type": "string",
                    "description": "The URL of the web page to screenshot (must be a valid HTTP/HTTPS URL)"
                ],
                "width": [
                    "type": "integer",
                    "description": "Viewport width in pixels (default: 1280)"
                ],
                "wait": [
                    "type": "number",
                    "description": "Additional wait time in seconds after page load before taking the screenshot, useful for JavaScript-heavy pages (default: 1.0, max: 10.0)"
                ]
            ],
            "required": ["url"]
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let urlString = arguments["url"]?.value as? String else {
            return "Error: Missing required 'url' parameter"
        }

        guard let url = URL(string: urlString) else {
            return "Error: Invalid URL format: \(urlString)"
        }

        guard url.scheme == "http" || url.scheme == "https" else {
            return "Error: Only HTTP/HTTPS URLs are supported"
        }

        let width = arguments["width"]?.value as? Int ?? 1280
        let waitSeconds = min(arguments["wait"]?.value as? Double ?? 1.0, 10.0)

        if Self.verbose {
            AppLogger.core.info("\(self.t)📸 Taking screenshot of: \(urlString)")
        }

        do {
            let screenshotPath = try await takeScreenshot(
                url: url,
                width: width,
                waitSeconds: waitSeconds
            )
            return screenshotPath
        } catch {
            if Self.verbose {
                AppLogger.core.error("\(self.t)❌ Screenshot failed: \(error.localizedDescription)")
            }
            return "Error: Failed to take screenshot - \(error.localizedDescription)"
        }
    }

    // MARK: - Screenshot Implementation

    /// 加载页面并截取截图
    @MainActor
    private func takeScreenshot(
        url: URL,
        width: Int,
        waitSeconds: Double
    ) async throws -> String {
        // 创建 WKWebView（非持久化数据存储，干净隔离）
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.preferences.javaScriptEnabled = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = false

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"

        // 加载页面
        let request = URLRequest(url: url)
        try await webView.loadAndWait(request, timeout: 30)

        // 额外等待，让 JS 渲染完成
        try await Task.sleep(for: .seconds(max(0.1, waitSeconds)))

        // 获取页面内容高度
        let contentHeight = try await webView.evaluateJavaScript("document.body.scrollHeight") as? Int ?? 800
        let finalHeight = max(contentHeight, 200)

        // 调整 WebView 尺寸以匹配完整页面
        webView.frame = CGRect(x: 0, y: 0, width: width, height: finalHeight)
        try await Task.sleep(for: .milliseconds(200))

        // 截图
        let snapshotConfig = WKSnapshotConfiguration()
        snapshotConfig.rect = CGRect(x: 0, y: 0, width: width, height: finalHeight)
        let image = try await webView.takeSnapshotAsync(with: snapshotConfig)

        // 转换为 PNG
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) else {
            throw ScreenshotError.imageConversionFailed
        }

        // 保存到临时目录
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "browser-screenshot-\(UUID().uuidString).png"
        let tempFile = tempDir.appendingPathComponent(filename)
        try pngData.write(to: tempFile)

        if Self.verbose {
            AppLogger.core.info("\(self.t)✅ Screenshot saved: \(tempFile.path)")
        }

        return tempFile.path
    }
}

// MARK: - WKWebView Extension

/// WKWebView 异步加载扩展
extension WKWebView {
    /// 加载请求并等待页面加载完成
    func loadAndWait(_ request: URLRequest, timeout: TimeInterval = 30) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let delegate = NavigationObserver()
            self.navigationDelegate = delegate

            delegate.onComplete = { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }

            self.load(request)

            // 超时保护
            Task {
                try? await Task.sleep(for: .seconds(timeout))
                delegate.onTimeout()
            }
        }
    }

    @MainActor
    func takeSnapshotAsync(with configuration: WKSnapshotConfiguration?) async throws -> NSImage {
        try await withCheckedThrowingContinuation { continuation in
            self.takeSnapshot(with: configuration) { image, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: ScreenshotError.imageConversionFailed)
                }
            }
        }
    }
}

/// 页面加载完成的观察者
private final class NavigationObserver: NSObject, WKNavigationDelegate, @unchecked Sendable {
    var onComplete: ((Error?) -> Void)?
    private var completed = false

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !completed else { return }
        completed = true
        onComplete?(nil)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard !completed else { return }
        completed = true
        onComplete?(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard !completed else { return }
        completed = true
        onComplete?(error)
    }

    func onTimeout() {
        guard !completed else { return }
        completed = true
        onComplete?(NSError(domain: "BrowserPlugin", code: -1, userInfo: [NSLocalizedDescriptionKey: "Page load timed out"]))
    }
}

// MARK: - Errors

enum ScreenshotError: LocalizedError {
    case imageConversionFailed

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Failed to convert screenshot to PNG format"
        }
    }
}
