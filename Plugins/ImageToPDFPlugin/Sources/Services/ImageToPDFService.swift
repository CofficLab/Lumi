import AppKit
import Foundation
import os
import PDFKit
import SuperLogKit

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
    /// - Returns: `AsyncStream<Double>` of progress values in `0.0...1.0`
    ///   that the caller can iterate on. The stream finishes after the
    ///   PDF has been written to disk or after an error has been logged.
    func convert(source: ImageItem, to outputURL: URL) -> AsyncStream<Double> {
        AsyncStream { continuation in
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
        continuation: AsyncStream<Double>.Continuation
    ) async {
        do {
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
        }

        continuation.finish()
    }

    /// Draw `image` into `context` so that it fills a page sized
    /// `pageSize` points. The CoreGraphics PDF coordinate system has a
    /// bottom-left origin, so the image's natural top-left origin is
    /// flipped before drawing.
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
        context.translateBy(x: 0, y: pageSize.height)
        context.scaleBy(x: 1, y: -1)
        let rect = CGRect(origin: .zero, size: pageSize)
        context.draw(cgImage, in: rect)
    }
}
