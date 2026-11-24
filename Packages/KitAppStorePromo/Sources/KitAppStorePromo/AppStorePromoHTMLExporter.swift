import AppKit
import CoreGraphics
import Foundation
import WebKit

public enum AppStorePromoExportError: LocalizedError, Equatable {
    case loadTimedOut
    case resourcesTimedOut
    case snapshotTimedOut
    case unexpectedImageSize(expectedWidth: Int, expectedHeight: Int, actualWidth: Int, actualHeight: Int)
    case pngEncodingFailed

    public var errorDescription: String? {
        switch self {
        case .loadTimedOut: "Timed out while loading promotional HTML."
        case .resourcesTimedOut: "Timed out while waiting for images and fonts."
        case .snapshotTimedOut: "Timed out while capturing promotional PNG."
        case .unexpectedImageSize(let expectedWidth, let expectedHeight, let actualWidth, let actualHeight):
            "Exported image size \(actualWidth)x\(actualHeight) does not match expected \(expectedWidth)x\(expectedHeight)."
        case .pngEncodingFailed: "Failed to encode promotional PNG."
        }
    }
}

@MainActor
public enum AppStorePromoHTMLExporter {
    public static func exportPNG(
        html: String,
        fileURL: URL?,
        readAccessRootURL: URL? = nil,
        preset: AppStorePromoDisplayPreset,
        loadTimeout: TimeInterval = 8,
        resourceTimeout: TimeInterval = 5
    ) async throws -> Data {
        try Task.checkCancellation()
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        let webView = WKWebView(frame: CGRect(origin: .zero, size: preset.cgSize), configuration: configuration)
        let delegate = LoadDelegate()
        webView.navigationDelegate = delegate

        if let fileURL {
            // 本地化 HTML 位于 localizations/ 子目录，需放行图片根目录才能读取
            // 上级的共享 assets（issue #1009）。
            webView.loadFileURL(
                fileURL,
                allowingReadAccessTo: readAccessRootURL ?? fileURL.deletingLastPathComponent()
            )
        } else {
            webView.loadHTMLString(html, baseURL: nil)
        }

        try Task.checkCancellation()
        guard await delegate.waitForFinish(timeout: loadTimeout) else { throw AppStorePromoExportError.loadTimedOut }
        try Task.checkCancellation()
        try await disableMotion(in: webView)
        guard try await waitForResources(in: webView, timeout: resourceTimeout) else {
            throw AppStorePromoExportError.resourcesTimedOut
        }

        let image = try await captureViewport(of: webView)
        let pointWidth = Int(image.size.width.rounded())
        let pointHeight = Int(image.size.height.rounded())
        guard pointWidth == preset.width, pointHeight == preset.height else {
            throw AppStorePromoExportError.unexpectedImageSize(
                expectedWidth: preset.width,
                expectedHeight: preset.height,
                actualWidth: pointWidth,
                actualHeight: pointHeight
            )
        }
        guard let sourceImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw AppStorePromoExportError.pngEncodingFailed
        }
        let box = ExportableCGImage(cgImage: sourceImage)
        let width = preset.width
        let height = preset.height
        return try await Task.detached(priority: .userInitiated) {
            try Self.encodePNG(sourceImage: box.cgImage, width: width, height: height)
        }.value
    }

    /// 在后台线程把快照归一化到目标像素尺寸并编码为 PNG。
    ///
    /// WKWebView snapshots use a Retina backing representation even though
    /// the CSS viewport is already the exact App Store point size.
    /// Rasterize that representation at one output pixel per CSS pixel so
    /// the encoded file has the required dimensions without changing layout.
    nonisolated static func encodePNG(sourceImage: CGImage, width: Int, height: Int) throws -> Data {
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw AppStorePromoExportError.pngEncodingFailed
        }
        context.interpolationQuality = .high
        context.draw(sourceImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let normalizedImage = context.makeImage(),
              let data = NSBitmapImageRep(cgImage: normalizedImage).representation(using: .png, properties: [:]) else {
            throw AppStorePromoExportError.pngEncodingFailed
        }
        return data
    }

    private struct ExportableCGImage: @unchecked Sendable {
        let cgImage: CGImage
    }

    private static func captureViewport(
        of webView: WKWebView,
        timeout: TimeInterval = 20
    ) async throws -> NSImage {
        // WebKit 的完成回调不保证送达；没有超时的话 continuation 永不恢复，
        // 调用方会永久挂起（见 Issue #127）。
        let state = SnapshotState()
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                state.attach(continuation)

                webView.takeSnapshot(with: nil) { image, error in
                    if let image {
                        state.finish(.success(image))
                    } else {
                        state.finish(.failure(error ?? AppStorePromoExportError.pngEncodingFailed))
                    }
                }

                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(timeout))
                    state.finish(.failure(AppStorePromoExportError.snapshotTimedOut))
                }
            }
        }, onCancel: {
            // 取消也要立即恢复等待方，否则已取消的导出仍要空等超时（#430）。
            Task { @MainActor in state.finish(.failure(CancellationError())) }
        })
    }

    /// `takeSnapshot` 的一次性完成状态。
    ///
    /// WebKit 回调与超时任务都可能先到，用一次性 `finish` 保证 continuation 只被恢复一次。
    @MainActor
    final class SnapshotState {
        private var continuation: CheckedContinuation<NSImage, Error>?
        private var completed = false

        func attach(_ continuation: CheckedContinuation<NSImage, Error>) {
            self.continuation = continuation
        }

        func finish(_ result: Result<NSImage, Error>) {
            guard !completed else { return }
            completed = true
            let pending = continuation
            continuation = nil
            switch result {
            case .success(let image): pending?.resume(returning: image)
            case .failure(let error): pending?.resume(throwing: error)
            }
        }
    }

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

    private static func waitForResources(in webView: WKWebView, timeout: TimeInterval) async throws -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        let script = """
        document.readyState === 'complete' &&
        Array.from(document.images).every(image => image.complete && image.naturalWidth > 0) &&
        (!document.fonts || document.fonts.status === 'loaded')
        """
        while Date() < deadline {
            try Task.checkCancellation()
            if let ready = try? await webView.evaluateJavaScript(script) as? Bool, ready { return true }
            try await Task.sleep(for: .milliseconds(50))
        }
        return false
    }

    private final class LoadDelegate: NSObject, WKNavigationDelegate {
        private var continuation: CheckedContinuation<Bool, Never>?
        private var completedResult: Bool?

        func waitForFinish(timeout: TimeInterval) async -> Bool {
            if let completedResult { return completedResult }
            return await withTaskCancellationHandler(operation: {
                await withCheckedContinuation { continuation in
                    self.continuation = continuation
                    Task { @MainActor [weak self] in
                        try? await Task.sleep(for: .seconds(timeout))
                        self?.finish(false)
                    }
                }
            }, onCancel: {
                // 取消也要立即唤醒等待方，否则已取消的导出仍要空等超时（#430）。
                Task { @MainActor [weak self] in self?.finish(false) }
            })
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
