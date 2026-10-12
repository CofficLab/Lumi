import AppKit
import CoreGraphics
import Foundation
import KitHTMLPreview
import WebKit

public enum PrototypeExportError: LocalizedError, Equatable {
    case loadTimedOut
    case resourcesTimedOut
    case unexpectedImageSize(expectedWidth: Int, expectedHeight: Int, actualWidth: Int, actualHeight: Int)
    case pngEncodingFailed

    public var errorDescription: String? {
        switch self {
        case .loadTimedOut: "Timed out while loading prototype HTML."
        case .resourcesTimedOut: "Timed out while waiting for images and fonts."
        case .unexpectedImageSize(let expectedWidth, let expectedHeight, let actualWidth, let actualHeight):
            "Rendered screen size \(actualWidth)x\(actualHeight) does not match the expected device size \(expectedWidth)x\(expectedHeight)."
        case .pngEncodingFailed: "Failed to encode prototype PNG."
        }
    }
}

/// 单屏原型 HTML → 精确像素 PNG。
///
/// 与 `AppStorePromoHTMLExporter` 的差异只有一处：目标尺寸不再来自固定的
/// App Store 展示枚举，而是**设备逻辑尺寸 × 导出倍率**。
///
/// 渲染按逻辑尺寸布置 CSS 视口（保证 `vmin`/百分比等相对单位与真机一致），
/// 再栅格化到 `pixelWidth × pixelHeight`，因此输出像素与 `scale` 精确对应。
@MainActor
public enum PrototypeHTMLExporter {

    /// 渲染一屏为 PNG。
    ///
    /// - Parameters:
    ///   - html: 完整 HTML 文档。
    ///   - fileURL: 屏幕 HTML 的文件地址；提供时按文件加载以正确解析 `../assets/` 相对资源。
    ///   - device: 画板设备，决定逻辑视口尺寸与输出像素。
    public static func exportPNG(
        html: String,
        fileURL: URL?,
        device: PrototypeDevice,
        loadTimeout: TimeInterval = 8,
        resourceTimeout: TimeInterval = 5
    ) async throws -> Data {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        let webView = WKWebView(
            frame: CGRect(origin: .zero, size: device.logicalSize),
            configuration: configuration
        )
        let delegate = LoadDelegate()
        webView.navigationDelegate = delegate

        if let fileURL {
            webView.loadFileURL(fileURL, allowingReadAccessTo: fileURL.deletingLastPathComponent())
        } else {
            webView.loadHTMLString(html, baseURL: nil)
        }

        guard await delegate.waitForFinish(timeout: loadTimeout) else { throw PrototypeExportError.loadTimedOut }
        try await disableMotion(in: webView)
        guard await waitForResources(in: webView, timeout: resourceTimeout) else {
            throw PrototypeExportError.resourcesTimedOut
        }

        let image = try await HTMLScreenshotter.capture(webView)
        let pointWidth = Int(image.size.width.rounded())
        let pointHeight = Int(image.size.height.rounded())
        guard pointWidth == Int(device.width.rounded()), pointHeight == Int(device.height.rounded()) else {
            throw PrototypeExportError.unexpectedImageSize(
                expectedWidth: Int(device.width.rounded()),
                expectedHeight: Int(device.height.rounded()),
                actualWidth: pointWidth,
                actualHeight: pointHeight
            )
        }

        let pixelWidth = device.pixelWidth
        let pixelHeight = device.pixelHeight
        guard let sourceImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let context = CGContext(
                data: nil,
                width: pixelWidth,
                height: pixelHeight,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            throw PrototypeExportError.pngEncodingFailed
        }
        // WKWebView 的 PDF 捕获会产生 Retina 后备表示，而它的 CSS 视口已经是
        // 精确的逻辑尺寸。这里按「一个输出像素对应一个 CSS 像素 × scale」重绘，
        // 既不改变布局，又让文件尺寸落在目标像素上。
        context.interpolationQuality = .high
        context.draw(sourceImage, in: CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
        guard let normalizedImage = context.makeImage(),
              let data = NSBitmapImageRep(cgImage: normalizedImage).representation(using: .png, properties: [:]) else {
            throw PrototypeExportError.pngEncodingFailed
        }
        return data
    }

    // MARK: - 私有

    private static func disableMotion(in webView: WKWebView) async throws {
        let script = """
        (() => {
          const style = document.createElement('style');
          style.textContent = '*,*::before,*::after{animation:none!important;transition:none!important;caret-color:transparent!important}';
          document.head.appendChild(style);
          return true;
        })()
        """
        _ = try await webView.evaluateJavaScript(script)
    }

    private static func waitForResources(in webView: WKWebView, timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        let script = """
        document.readyState === 'complete' &&
        Array.from(document.images).every(image => image.complete && image.naturalWidth > 0) &&
        (!document.fonts || document.fonts.status === 'loaded')
        """
        while Date() < deadline {
            if let ready = try? await webView.evaluateJavaScript(script) as? Bool, ready { return true }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return false
    }

    private final class LoadDelegate: NSObject, WKNavigationDelegate {
        private var continuation: CheckedContinuation<Bool, Never>?
        private var completedResult: Bool?

        func waitForFinish(timeout: TimeInterval) async -> Bool {
            if let completedResult { return completedResult }
            return await withCheckedContinuation { continuation in
                self.continuation = continuation
                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .seconds(timeout))
                    self?.finish(false)
                }
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { finish(true) }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { finish(false) }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { finish(false) }

        private func finish(_ success: Bool) {
            guard completedResult == nil else { return }
            completedResult = success
            continuation?.resume(returning: success)
            continuation = nil
        }
    }
}
