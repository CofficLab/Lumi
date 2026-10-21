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
    /// - Parameters:
    ///   - webView: 已加载 HTML 内容的 `WKWebView` 实例
    ///   - timeout: 等待 WebKit 生成 PDF 的最长时间（秒）。超时抛 `HTMLError.renderTimedOut`。
    /// - Returns: 包含完整页面内容的 `NSImage`
    ///
    /// - Note: `WKWebView.createPDF` 的完成回调**不保证**一定送达。若 WebKit 进程
    ///   状态异常或页面始终无法完成布局，回调可能永不到达，此时 continuation 永不恢复，
    ///   调用方（以及 `swift test` 进程）会永久挂起。因此这里必须带超时保护。
    public static func capture(_ webView: WKWebView, timeout: TimeInterval = 30) async throws -> NSImage {
        let pdfData = try await createPDF(from: webView, timeout: timeout)

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

        // NSImage.lockFocus() 创建的 CGContext 原点位于左下角，Y 轴向上，
        // 与 PDF 坐标系一致。PDFPage.draw() 内部会自行处理坐标映射，
        // 所以不需要额外翻转。
        // 但页面需要反向绘制：先画最后一页到图像底部，再画第一页到图像顶部。
        // 这样用户在左上角原点的图像中看到的就是正确从上到下的 HTML 内容。
        var currentY: CGFloat = 0
        for (index, bounds) in pageBounds.enumerated().reversed() {
            guard let page = pdfDocument.page(at: index) else { continue }

            cgContext.saveGState()
            cgContext.translateBy(x: 0, y: currentY)

            page.draw(with: .mediaBox, to: cgContext)

            cgContext.restoreGState()
            currentY += bounds.height
        }

        image.unlockFocus()
        return image
    }

    /// 调用 `WKWebView.createPDF` 并等待结果，带超时保护。
    ///
    /// WebKit 的完成回调不保证送达；没有超时的话，未送达时 continuation 永不恢复，
    /// 调用方会永久挂起（见 Issue #127）。
    private static func createPDF(from webView: WKWebView, timeout: TimeInterval) async throws -> Data {
        let state = PDFRequestState()
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            state.attach(continuation)

            webView.createPDF { result in
                switch result {
                case .success(let data):
                    state.finish(.success(data))
                case .failure(let error):
                    state.finish(.failure(error))
                }
            }

            // 超时兜底：回调永不到达时也要恢复 continuation，否则调用方永久挂起。
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(timeout))
                state.finish(.failure(HTMLError.renderTimedOut))
            }
        }
    }

    /// `createPDF` 的一次性完成状态。
    ///
    /// WebKit 回调与超时任务都可能先到，用一次性 `finish` 保证 continuation 只被恢复一次。
    @MainActor
    final class PDFRequestState {
        private var continuation: CheckedContinuation<Data, Error>?
        private var completed = false

        /// 是否已经完成（用于断言「continuation 只被恢复一次」）。
        var isCompleted: Bool { completed }

        func attach(_ continuation: CheckedContinuation<Data, Error>) {
            self.continuation = continuation
        }

        func finish(_ result: Result<Data, Error>) {
            guard !completed else { return }
            completed = true
            let pending = continuation
            continuation = nil
            switch result {
            case .success(let data): pending?.resume(returning: data)
            case .failure(let error): pending?.resume(throwing: error)
            }
        }
    }
}

// MARK: - Error

extension HTMLScreenshotter {
    public enum HTMLError: Error, LocalizedError {
        case pdfCreationFailed
        case emptyDocument
        case renderingFailed(String)
        /// 等待 WebKit 渲染结果超时。
        case renderTimedOut

        public var errorDescription: String? {
            switch self {
            case .pdfCreationFailed:
                return "Failed to create PDF from HTML content"
            case .emptyDocument:
                return "PDF document is empty"
            case .renderingFailed(let msg):
                return "Rendering failed: \(msg)"
            case .renderTimedOut:
                return "Timed out while rendering HTML content"
            }
        }
    }
}
