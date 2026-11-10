import AppKit
import Foundation
import os
import PDFKit
import LumiLoggingKit
/// Converts images into single-page PDF files using CoreGraphics.
///
/// The service is a stateless final class — it doesn't hold any mutable
/// state, so it can be safely called from any actor or the main thread.
/// Long-running conversions are offloaded to the cooperative pool via
/// `Task.detached` so the UI stays responsive even with many files.
final class ImageToPDFService: SuperLog, @unchecked Sendable {
    nonisolated static let emoji = "🖼️"
    nonisolated static let verbose: Bool = false
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.image-to-pdf"
    )

    init() {}

    // MARK: - Errors

    /// Failures that occur while converting a single image into a PDF.
    enum ConversionError: LocalizedError {
        case imageLoadFailed(URL)
        case zeroSizedImage(URL)
        case pdfContextFailed(URL)
        case writeFailed(URL)

        var errorDescription: String? {
            switch self {
            case .imageLoadFailed(let url):
                return ImageToPDFLocalization.string(
                    "Could not read image: %@",
                    url.lastPathComponent
                )
            case .zeroSizedImage(let url):
                return ImageToPDFLocalization.string(
                    "Image has zero size: %@",
                    url.lastPathComponent
                )
            case .pdfContextFailed(let url):
                return ImageToPDFLocalization.string(
                    "Failed to create PDF context for: %@",
                    url.lastPathComponent
                )
            case .writeFailed(let url):
                return ImageToPDFLocalization.string(
                    "Failed to write PDF: %@",
                    url.lastPathComponent
                )
            }
        }
    }

    // MARK: - Public API

    /// Convert a single image to a PDF at `outputURL`.
    ///
    /// - Returns: `AsyncThrowingStream<Double, Error>` of progress values in
    ///   `0.0...1.0`. The stream finishes after the PDF has been written, or
    ///   throws when the image cannot be read or the PDF cannot be written.
    func convert(source: ImageItem, to outputURL: URL) -> AsyncThrowingStream<Double, Error> {
        AsyncThrowingStream { continuation in
            let task = Task.detached(priority: .userInitiated) {
                await Self.runConversion(
                    source: source,
                    outputURL: outputURL,
                    continuation: continuation
                )
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Conversion Pipeline

    /// Run the conversion off the main thread, yielding progress through
    /// `continuation`.
    private static func runConversion(
        source: ImageItem,
        outputURL: URL,
        continuation: AsyncThrowingStream<Double, Error>.Continuation
    ) async {
        do {
            // 先清掉上一轮遗留的同名文件：否则本次失败时旧的 PDF 会被误认为成功产物。
            try? FileManager.default.removeItem(at: outputURL)

            continuation.yield(0.1)

            guard let image = NSImage(contentsOf: source.url) else {
                throw ConversionError.imageLoadFailed(source.url)
            }
            guard image.size.width > 0, image.size.height > 0 else {
                throw ConversionError.zeroSizedImage(source.url)
            }

            continuation.yield(0.3)

            let pageSize = image.size
            let pdfData = NSMutableData()

            guard let consumer = CGDataConsumer(data: pdfData) else {
                throw ConversionError.pdfContextFailed(source.url)
            }

            var mediaBox = CGRect(origin: .zero, size: pageSize)
            guard let context = CGContext(
                consumer: consumer,
                mediaBox: &mediaBox,
                nil
            ) else {
                throw ConversionError.pdfContextFailed(source.url)
            }

            continuation.yield(0.5)

            context.beginPage(mediaBox: &mediaBox)
            drawImage(image, in: context, pageSize: pageSize)
            context.endPage()
            context.closePDF()

            continuation.yield(0.9)

            do {
                try FileManager.default.createDirectory(
                    at: outputURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try (pdfData as Data).write(to: outputURL, options: .atomic)
            } catch {
                throw ConversionError.writeFailed(source.url)
            }

            continuation.yield(1.0)

            if Self.verbose {
                Self.logger.info(
                    "\(Self.t)Converted \(source.lastPathComponent) → \(outputURL.lastPathComponent) (\(pageSize.width)×\(pageSize.height) pt)"
                )
            }
        } catch {
            let message = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
            Self.logger.error("\(Self.t)Failed to convert \(source.lastPathComponent): \(message)")
            // 把失败传给调用方，避免用「目标文件是否存在」猜结果。
            continuation.finish(throwing: error)
            return
        }

        continuation.finish()
    }

    /// Draw `image` into `context` so that it fills a page sized
    /// `pageSize` points.
    ///
    /// 不做额外垂直翻转：`CGContext.draw` 在 PDF 上下文中已经按图片自身的
    /// 行顺序写入 image XObject，再叠加 `translate` + `scale(y: -1)` 会让
    /// 输出上下镜像（文字倒置）。
    private static func drawImage(
        _ image: NSImage,
        in context: CGContext,
        pageSize: CGSize
    ) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return
        }
        context.saveGState()
        defer { context.restoreGState() }
        let rect = CGRect(origin: .zero, size: pageSize)
        context.draw(cgImage, in: rect)
    }
}
