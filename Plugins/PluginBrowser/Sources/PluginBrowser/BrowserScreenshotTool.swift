import AgentToolKit
import AppKit
import Foundation
import SuperLogKit
import WebKit
import os

/// 网页截图工具。
///
/// 使用 WKWebView 渲染指定 URL 的网页，等待页面加载完成后截取完整截图。
/// 截图保存到系统临时目录，返回文件路径。
public struct BrowserScreenshotTool: SuperAgentTool, SuperLog {
    public nonisolated static let emoji = "📸"
    public nonisolated static let verbose: Bool = true

    private nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.browser.tool")

    public let name = "browser_screenshot"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return """
截取渲染后网页的截图。使用 WKWebView 加载并渲染页面，然后截取整页截图并保存到临时文件。

当需要视觉检查网页，或基于文本的抓取工具（web_fetch）不足以处理时使用此工具，例如 JavaScript 较重的页面、SPA、需要登录 Cookie 的页面。

返回保存后的 PNG 截图文件路径。
"""
        case .english:
            return """
Take a screenshot of a rendered web page. Uses WKWebView to load and render the page, then captures a full-page screenshot saved to a temporary file.

Use this tool when you need to visually inspect a web page or when text-based fetching (web_fetch) is insufficient (e.g., JavaScript-heavy pages, SPAs, pages that require login cookies).

Returns the file path of the saved screenshot image (PNG format).
"""
        }
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "url": [
                    "type": "string",
                    "description": "The URL of the web page to screenshot (must be a valid HTTP/HTTPS URL)",
                ],
                "width": [
                    "type": "integer",
                    "description": "Viewport width in pixels (default: 1280)",
                ],
                "wait": [
                    "type": "number",
                    "description": "Additional wait time in seconds after page load before taking the screenshot, useful for JavaScript-heavy pages (default: 1.0, max: 10.0)",
                ],
            ],
            "required": ["url"],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "网页截图"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium
    }

    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        try context.checkCancellation()
        return try await executeScreenshot(arguments: arguments, context: context)
    }

    private func executeScreenshot(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        guard let rawURLString = arguments["url"]?.value as? String else {
            return "Error: Missing required 'url' parameter"
        }
        guard let url = Self.normalizedURL(from: rawURLString) else {
            return "Error: Invalid URL format: \(rawURLString)"
        }

        guard url.scheme == "http" || url.scheme == "https" else {
            return "Error: Only HTTP/HTTPS URLs are supported"
        }

        let width = arguments["width"]?.value as? Int ?? 1280
        let waitSeconds = min(arguments["wait"]?.value as? Double ?? 1.0, 10.0)

        if Self.verbose {
            Self.logger.info("\(Self.t)📸 Taking screenshot of: \(url.absoluteString)")
        }

        do {
            try context.checkCancellation()
            let screenshotPath = try await takeScreenshot(
                url: url,
                width: width,
                waitSeconds: waitSeconds,
                context: context
            )
            try context.checkCancellation()
            return screenshotPath
        } catch {
            if Self.verbose {
                Self.logger.error("\(Self.t)❌ Screenshot failed: \(error.localizedDescription)")
            }
            return "Error: Failed to take screenshot - \(error.localizedDescription)"
        }
    }

    static func normalizedURL(from rawURLString: String) -> URL? {
        let urlString = rawURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !urlString.isEmpty else { return nil }
        return URL(string: urlString)
    }

    // MARK: - Screenshot Implementation

    /// 加载页面并截取截图
    @MainActor
    private func takeScreenshot(
        url: URL,
        width: Int,
        waitSeconds: Double,
        context: ToolExecutionContext
    ) async throws -> String {
        try context.checkCancellation()
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.preferences.javaScriptEnabled = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = false

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"

        let request = URLRequest(url: url)
        try await webView.loadAndWait(request, timeout: 30, context: context)
        try context.checkCancellation()

        try await Task.sleep(for: .seconds(max(0.1, waitSeconds)))
        try context.checkCancellation()

        let contentHeight = try await webView.evaluateJavaScript("document.body.scrollHeight") as? Int ?? 800
        let finalHeight = max(contentHeight, 200)

        webView.frame = CGRect(x: 0, y: 0, width: width, height: finalHeight)
        try await Task.sleep(for: .milliseconds(200))
        try context.checkCancellation()

        let snapshotConfig = WKSnapshotConfiguration()
        snapshotConfig.rect = CGRect(x: 0, y: 0, width: width, height: finalHeight)
        let image = try await webView.takeSnapshotAsync(with: snapshotConfig)

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: NSBitmapImageRep.FileType.png, properties: [:])
        else {
            throw ScreenshotError.imageConversionFailed
        }

        let tempDir = FileManager.default.temporaryDirectory
        let filename = "browser-screenshot-\(UUID().uuidString).png"
        let tempFile = tempDir.appendingPathComponent(filename)
        try pngData.write(to: tempFile)

        if Self.verbose {
            Self.logger.info("\(Self.t)✅ Screenshot saved: \(tempFile.path)")
        }

        return tempFile.path
    }
}

// MARK: - WKWebView Extension

extension WKWebView {
    /// 加载请求并等待页面加载完成
    func loadAndWait(_ request: URLRequest, timeout: TimeInterval = 30, context: ToolExecutionContext) async throws {
        try context.checkCancellation()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                let delegate = NavigationObserver()
                self.navigationDelegate = delegate
                let cancellationHandlerId = context.onCancel { [weak self, weak delegate] in
                    Task { @MainActor in
                        self?.stopLoading()
                        delegate?.onCancel()
                    }
                }

                delegate.onComplete = { error in
                    context.removeCancellationHandler(cancellationHandlerId)
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }

                self.load(request)

                Task {
                    try? await Task.sleep(for: .seconds(timeout))
                    delegate.onTimeout()
                }
            }
        } onCancel: { [weak self] in
            context.cancel()
            Task { @MainActor in
                self?.stopLoading()
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

// MARK: - Navigation Observer

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

    func onCancel() {
        guard !completed else { return }
        completed = true
        onComplete?(CancellationError())
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
