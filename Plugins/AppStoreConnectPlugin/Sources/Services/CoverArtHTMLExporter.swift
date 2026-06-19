import AppKit
import Foundation
import HTMLPreviewKit
import WebKit

@MainActor
enum CoverArtHTMLExporter {
    enum ExportError: LocalizedError {
        case loadTimedOut
        case unexpectedImageSize(expected: ScreenshotDisplaySpec.Size, actualWidth: Int, actualHeight: Int)
        case pngEncodingFailed

        var errorDescription: String? {
            switch self {
            case .loadTimedOut:
                return AppStoreConnectLocalization.string("Timed out while loading cover art HTML.")
            case .unexpectedImageSize(let expected, let actualWidth, let actualHeight):
                return AppStoreConnectLocalization.string(
                    "Exported image size %dx%d does not match expected %dx%d.",
                    actualWidth,
                    actualHeight,
                    expected.width,
                    expected.height
                )
            case .pngEncodingFailed:
                return AppStoreConnectLocalization.string("Failed to encode PNG.")
            }
        }
    }

    static func exportPNG(
        html: String,
        fileURL: URL?,
        expectedSize: ScreenshotDisplaySpec.Size,
        tolerance: Int = 1
    ) async throws -> Data {
        let webView = WKWebView(frame: CGRect(origin: .zero, size: expectedSize.cgSize))
        let delegate = LoadDelegate()
        webView.navigationDelegate = delegate

        if let fileURL {
            webView.loadFileURL(fileURL, allowingReadAccessTo: fileURL.deletingLastPathComponent())
        } else {
            webView.loadHTMLString(html, baseURL: nil)
        }

        let loaded = await delegate.waitForFinish(timeout: 8)
        guard loaded else { throw ExportError.loadTimedOut }

        try await Task.sleep(for: .milliseconds(150))

        let image = try await HTMLScreenshotter.capture(webView)
        guard let rep = image.representations.first else {
            throw ExportError.pngEncodingFailed
        }

        let widthDelta = abs(rep.pixelsWide - expectedSize.width)
        let heightDelta = abs(rep.pixelsHigh - expectedSize.height)
        guard widthDelta <= tolerance, heightDelta <= tolerance else {
            throw ExportError.unexpectedImageSize(
                expected: expectedSize,
                actualWidth: rep.pixelsWide,
                actualHeight: rep.pixelsHigh
            )
        }

        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw ExportError.pngEncodingFailed
        }
        return pngData
    }

    private final class LoadDelegate: NSObject, WKNavigationDelegate {
        private var continuation: CheckedContinuation<Bool, Never>?

        func waitForFinish(timeout: TimeInterval) async -> Bool {
            await withCheckedContinuation { continuation in
                self.continuation = continuation
                Task {
                    try? await Task.sleep(for: .seconds(timeout))
                    self.finish(success: false)
                }
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            finish(success: true)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            finish(success: false)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            finish(success: false)
        }

        private func finish(success: Bool) {
            guard let continuation else { return }
            self.continuation = nil
            continuation.resume(returning: success)
        }
    }
}
