import CoreGraphics
import Foundation
import os
import SuperLogKit

// MARK: - Booklet Renderer

/// Renders an impositioned PDF using CoreGraphics.
///
/// The renderer streams the source PDF page by page and writes one
/// output sheet at a time, so memory usage stays roughly constant
/// regardless of input size. It exposes progress through an
/// `AsyncStream<Double>` so the UI can render a progress bar.
final class BookletRenderer: SuperLog, @unchecked Sendable {

    // MARK: - Identity

    nonisolated static let emoji = "📖"
    nonisolated static let verbose: Bool = false
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.booklet-maker.renderer"
    )

    init() {}

    // MARK: - Errors

    enum RenderError: LocalizedError {
        case sourceUnreadable(URL)
        case outputContextFailed(URL)
        case writeFailed(URL)

        var errorDescription: String? {
            switch self {
            case .sourceUnreadable(let url):
                return BookletLocalization.string("Could not open source PDF: %@", url.lastPathComponent)
            case .outputContextFailed(let url):
                return BookletLocalization.string("Could not create output PDF context: %@", url.lastPathComponent)
            case .writeFailed(let url):
                return BookletLocalization.string("Could not write output PDF: %@", url.lastPathComponent)
            }
        }
    }

    // MARK: - Public API

    /// Render an impositioned PDF.
    ///
    /// - Parameters:
    ///   - sourceURL: the input PDF.
    ///   - outputURL: where to write the result (will be overwritten).
    ///   - settings: imposition parameters.
    /// - Returns: an `AsyncStream<Double>` yielding progress values in
    ///   `0.0 ... 1.0`. The stream finishes after the file has been
    ///   written or after an error has been logged.
    func render(sourceURL: URL,
                outputURL: URL,
                settings: BookletSettings) -> AsyncStream<Double> {
        AsyncStream { continuation in
            let task = Task.detached(priority: .userInitiated) {
                await Self.runRender(sourceURL: sourceURL,
                                     outputURL: outputURL,
                                     settings: settings,
                                     continuation: continuation)
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Render pipeline

    private static func runRender(sourceURL: URL,
                                  outputURL: URL,
                                  settings: BookletSettings,
                                  continuation: AsyncStream<Double>.Continuation) async {
        do {
            continuation.yield(0.05)

            // 1. Open the source.
            guard let sourceDoc = CGPDFDocument(sourceURL as CFURL) else {
                throw RenderError.sourceUnreadable(sourceURL)
            }
            if sourceDoc.isEncrypted {
                throw RenderError.sourceUnreadable(sourceURL)
            }
            let rawCount = sourceDoc.numberOfPages
            guard rawCount > 0 else {
                throw RenderError.sourceUnreadable(sourceURL)
            }

            // 2. Plan the output PDF pages. In booklet mode consecutive
            // pages are the front and back of one physical sheet.
            let outputSides = BookletLayoutEngine.buildOutputSides(
                inputPageCount: rawCount,
                settings: settings
            )
            guard !outputSides.isEmpty else {
                throw RenderError.sourceUnreadable(sourceURL)
            }

            // 3. Build the output PDF context.
            let outputData = NSMutableData()
            guard let consumer = CGDataConsumer(data: outputData) else {
                throw RenderError.outputContextFailed(outputURL)
            }
            // Booklet sheets are printed in landscape so the two reduced
            // portrait source pages sit side by side across the long edge.
            var mediaBox = CGRect(origin: .zero,
                                  size: settings.outputPaper.landscapeSizeInPoints)
            guard let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
                throw RenderError.outputContextFailed(outputURL)
            }

            // 4. Render every print side as one output PDF page.
            let total = outputSides.count
            for (i, outputSide) in outputSides.enumerated() {
                if Task.isCancelled { break }

                ctx.beginPDFPage(nil)

                // Source pages may differ in size; we read each one
                // and fit it into the corresponding cell.
                let leftRect  = BookletLayoutEngine.leftRect(for: settings)
                let rightRect = BookletLayoutEngine.rightRect(for: settings)

                drawPage(from: sourceDoc,
                         pageNumber: outputSide.leftPage,
                         into: leftRect,
                         context: ctx)

                drawPage(from: sourceDoc,
                         pageNumber: outputSide.rightPage,
                         into: rightRect,
                         context: ctx)

                if settings.addCutMarks {
                    drawCutMarks(in: leftRect, context: ctx)
                    drawCutMarks(in: rightRect, context: ctx)
                }

                ctx.endPDFPage()

                // Progress: 5% reserved for setup, 90% for rendering,
                // 5% reserved for finalisation.
                let p = 0.05 + 0.90 * Double(i + 1) / Double(total)
                continuation.yield(p)
            }

            ctx.closePDF()

            // 5. Write to disk.
            do {
                try FileManager.default.createDirectory(
                    at: outputURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true)
                try (outputData as Data).write(to: outputURL, options: .atomic)
            } catch {
                throw RenderError.writeFailed(outputURL)
            }

            continuation.yield(1.0)

            if Self.verbose {
                let physicalSheets = BookletLayoutEngine.buildPhysicalSheets(
                    inputPageCount: rawCount,
                    settings: settings
                ).count
                Self.logger.info("\(Self.t)Imposed \(rawCount) source pages → \(physicalSheets) physical sheets / \(total) print sides → \(outputURL.lastPathComponent)")
            }
        } catch {
            let message = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
            Self.logger.error("\(Self.t)Render failed: \(message)")
        }

        continuation.finish()
    }

    // MARK: - Drawing helpers

    /// Draw the 1-based `pageNumber` of `doc` (0 → blank) into `cellRect`,
    /// preserving the source page's aspect ratio. CGPDF uses a
    /// bottom-left coordinate system; the caller already set up the
    /// output context in points, so no extra flipping is required.
    private static func drawPage(from doc: CGPDFDocument,
                                 pageNumber: Int,
                                 into cellRect: CGRect,
                                 context ctx: CGContext) {
        guard pageNumber > 0, let page = doc.page(at: pageNumber) else {
            return // blank cell
        }
        let pageBox = page.getBoxRect(.mediaBox)
        guard pageBox.width > 0, pageBox.height > 0 else { return }

        let aspect = pageBox.width / pageBox.height
        let target = BookletLayoutEngine.fitRect(aspectRatio: aspect, into: cellRect)

        ctx.saveGState()
        defer { ctx.restoreGState() }

        // CGPDFPage draws in its own user space, defined by its media
        // box. We need to map the media box to the cell rect, so we
        // install a transform that scales and translates.
        let scaleX = target.width  / pageBox.width
        let scaleY = target.height / pageBox.height
        ctx.translateBy(x: target.minX, y: target.minY)
        ctx.scaleBy(x: scaleX, y: scaleY)
        // Media box may not start at (0, 0); shift accordingly.
        ctx.translateBy(x: -pageBox.minX, y: -pageBox.minY)

        ctx.drawPDFPage(page)
    }

    /// Draw four small tick marks at the corners of `rect` to act as
    /// cutting guides.
    private static func drawCutMarks(in rect: CGRect, context ctx: CGContext) {
        let length: CGFloat = 6 // points
        ctx.saveGState()
        defer { ctx.restoreGState() }
        ctx.setStrokeColor(gray: 0.6, alpha: 1.0)
        ctx.setLineWidth(0.4)

        let corners: [(CGPoint, CGPoint, CGPoint)] = [
            // (corner, line end 1, line end 2)
            (CGPoint(x: rect.minX, y: rect.minY),
             CGPoint(x: rect.minX - length, y: rect.minY),
             CGPoint(x: rect.minX, y: rect.minY - length)),
            (CGPoint(x: rect.maxX, y: rect.minY),
             CGPoint(x: rect.maxX + length, y: rect.minY),
             CGPoint(x: rect.maxX, y: rect.minY - length)),
            (CGPoint(x: rect.minX, y: rect.maxY),
             CGPoint(x: rect.minX - length, y: rect.maxY),
             CGPoint(x: rect.minX, y: rect.maxY + length)),
            (CGPoint(x: rect.maxX, y: rect.maxY),
             CGPoint(x: rect.maxX + length, y: rect.maxY),
             CGPoint(x: rect.maxX, y: rect.maxY + length)),
        ]
        for (_, a, b) in corners {
            ctx.move(to: a)
            ctx.addLine(to: b)
        }
        ctx.strokePath()
    }
}
