import AppKit
import PDFKit
import WebKit

/// HTML WebView 全页截图工具。
///
/// 使用 `WKWebView.createPDF` 生成完整页面 PDF，再用 CoreGraphics 逐页渲染到 `NSImage`。
/// 完全绕开 `takeSnapshot` 的 tile-based 渲染限制，不会出现黑色未渲染区域。
@MainActor
public struct HTMLScreenshotter {

    /// 截取 WebView 完整页面内容，返回 `NSImage`。
    ///
    /// - Parameter webView: 已加载 HTML 内容的 `WKWebView` 实例
    /// - Returns: 包含完整页面内容的 `NSImage`
    public static func capture(_ webView: WKWebView) async throws -> NSImage {
        let pdfData = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            webView.createPDF { result in
                switch result {
                case .success(let data):
                    continuation.resume(returning: data)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }

        guard let pdfDocument = PDFDocument(data: pdfData) else {
            throw HTMLError.pdfCreationFailed
        }

        let pageCount = pdfDocument.pageCount
        guard pageCount > 0 else {
            throw HTMLError.emptyDocument
        }

        // 计算所有页面的总尺寸
        var totalHeight: CGFloat = 0
        var maxWidth: CGFloat = 0
        var pageBounds: [CGRect] = []

        for i in 0..<pageCount {
            guard let page = pdfDocument.page(at: i) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            pageBounds.append(bounds)
            totalHeight += bounds.height
            maxWidth = max(maxWidth, bounds.width)
        }

        guard totalHeight > 0, maxWidth > 0 else {
            throw HTMLError.emptyDocument
        }

        let imageSize = NSSize(width: maxWidth, height: totalHeight)
        let image = NSImage(size: imageSize)
        image.lockFocus()

        // 填充白色背景
        NSColor.white.set()
        NSRect(origin: .zero, size: imageSize).fill()

        guard let context = NSGraphicsContext.current else {
            image.unlockFocus()
            throw HTMLError.renderingFailed("Failed to get graphics context")
        }

        let cgContext = context.cgContext

        // 关键：CGContext 默认原点在左下，Y 向上
        // 我们需要将原点移到左上，Y 向下（匹配 PDF 的 CSS 坐标系）
        cgContext.translateBy(x: 0, y: CGFloat(ceil(totalHeight)))
        cgContext.scaleBy(x: 1, y: -1)

        var currentY: CGFloat = 0
        for (index, bounds) in pageBounds.enumerated() {
            guard let page = pdfDocument.page(at: index) else { continue }

            // 在翻转后的坐标系中（原点左上，Y 向下），直接将页面画在正确位置
            cgContext.saveGState()
            cgContext.translateBy(x: 0, y: currentY)

            // draw 方法会再次翻转 Y 轴（因为它认为 CGContext 是 Y 向上）
            // 但我们已经翻转了，所以最终方向正确
            page.draw(with: .mediaBox, to: cgContext)

            cgContext.restoreGState()
            currentY += bounds.height
        }

        image.unlockFocus()
        return image
    }
}

// MARK: - Error

extension HTMLScreenshotter {
    public enum HTMLError: Error, LocalizedError {
        case pdfCreationFailed
        case emptyDocument
        case renderingFailed(String)

        public var errorDescription: String? {
            switch self {
            case .pdfCreationFailed:
                return "Failed to create PDF from HTML content"
            case .emptyDocument:
                return "PDF document is empty"
            case .renderingFailed(let msg):
                return "Rendering failed: \(msg)"
            }
        }
    }
}
