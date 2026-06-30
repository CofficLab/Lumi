import AppKit
import Foundation
import LumiCoreKit
import SuperLogKit
import WebKit
import os

/// 网页截图工具。
///
/// 使用 WKWebView 渲染指定 URL 的网页，等待页面加载完成后截取完整截图。
/// 截图保存到系统临时目录，返回文件路径。
public struct BrowserScreenshotTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "📸"
    public nonisolated static let verbose: Bool = false

    private nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.browser.tool")

    public static let info = LumiAgentToolInfo(
        id: "browser_screenshot",
        displayName: LumiPluginLocalization.string("Browser Screenshot", bundle: .module),
        description: LumiPluginLocalization.string(
            "Take a screenshot of a rendered web page. Uses WKWebView to load and render the page, then captures a full-page screenshot saved to a temporary file. Use this tool when you need to visually inspect a web page or when text-based fetching (web_fetch) is insufficient (e.g., JavaScript-heavy pages, SPAs, pages that require login cookies). Returns the file path of the saved screenshot image (PNG format).",
            bundle: .module
        )
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "url": .object([
                    "type": .string("string"),
                    "description": .string("The URL of the web page to screenshot (must be a valid HTTP/HTTPS URL)")
                ]),
                "width": .object([
                    "type": .string("integer"),
                    "description": .string("Viewport width in pixels (default: 1280, max: 4096)"),
                    "minimum": .int(1),
                    "maximum": .int(4096)
                ]),
                "wait": .object([
                    "type": .string("number"),
                    "description": .string("Additional wait time in seconds after page load before taking the screenshot, useful for JavaScript-heavy pages (default: 1.0, max: 10.0)"),
                    "minimum": .double(0),
                    "maximum": .double(10)
                ])
            ]),
            "required": .array([.string("url")])
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "网页截图"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .medium
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        try context.checkCancellation()
        return try await executeScreenshot(arguments: arguments, context: context)
    }

    private func executeScreenshot(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let rawURLString = arguments["url"]?.stringValue else {
            return "Error: Missing required 'url' parameter"
        }
        guard let url = Self.normalizedURL(from: rawURLString) else {
            return "Error: Invalid URL format: \(rawURLString)"
        }

        guard Self.isSupportedHTTPURL(url) else {
            return "Error: Only HTTP/HTTPS URLs are supported"
        }

        let width = Self.normalizedViewportWidth(from: arguments["width"]?.anyValue)
        let waitSeconds = Self.normalizedWaitSeconds(from: arguments["wait"]?.anyValue)

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

    static func isSupportedHTTPURL(_ url: URL) -> Bool {
        let scheme = url.scheme?.lowercased()
        return scheme == "http" || scheme == "https"
    }

    static func normalizedViewportWidth(from value: Any?) -> Int {
        let defaultWidth = 1280
        let maxWidth = 4096

        let width: Int?
        switch value {
        case let int as Int:
            width = int
        case let double as Double where double.isFinite:
            width = Int(double)
        case let string as String:
            width = Int(string.trimmingCharacters(in: .whitespacesAndNewlines))
        default:
            width = nil
        }

        guard let width, width > 0 else { return defaultWidth }
        return min(width, maxWidth)
    }

    static func normalizedWaitSeconds(from value: Any?) -> Double {
        let defaultWait = 1.0
        let maxWait = 10.0

        let wait: Double?
        switch value {
        case let double as Double:
            wait = double
        case let int as Int:
            wait = Double(int)
        case let string as String:
            wait = Double(string.trimmingCharacters(in: .whitespacesAndNewlines))
        default:
            wait = nil
        }

        guard let wait, wait.isFinite else { return defaultWait }
        return min(max(wait, 0), maxWait)
    }

    static func normalizedContentHeight(from value: Any?, defaultHeight: Int = 800) -> Int {
        let height: Int?
        switch value {
        case let int as Int:
            height = int
        case let double as Double where double.isFinite:
            height = Int(double.rounded(.up))
        case let number as NSNumber:
            let double = number.doubleValue
            height = double.isFinite ? Int(double.rounded(.up)) : nil
        case let string as String:
            height = Double(string.trimmingCharacters(in: .whitespacesAndNewlines))
                .flatMap { $0.isFinite ? Int($0.rounded(.up)) : nil }
        default:
            height = nil
        }

        guard let height, height > 0 else { return defaultHeight }
        return height
    }

    // MARK: - Screenshot Implementation

    /// 加载页面并截取截图
    @MainActor
    private func takeScreenshot(
        url: URL,
        width: Int,
        waitSeconds: Double,
        context: LumiToolExecutionContext
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

        let rawContentHeight = try await webView.evaluateJavaScript("""
        Math.max(
            document.body ? document.body.scrollHeight : 0,
            document.body ? document.body.offsetHeight : 0,
            document.documentElement ? document.documentElement.clientHeight : 0,
            document.documentElement ? document.documentElement.scrollHeight : 0,
            document.documentElement ? document.documentElement.offsetHeight : 0
        )
        """)
        let contentHeight = Self.normalizedContentHeight(from: rawContentHeight)
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
    func loadAndWait(_ request: URLRequest, timeout: TimeInterval = 30, context: LumiToolExecutionContext) async throws {
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
