import AppKit
import CoreGraphics
import Foundation
import os
import PDFKit
import SuperLogKit

// MARK: - Booklet Thumbnailer

/// Generates small PNG previews of the first few sheets of an
/// impositioned PDF so the UI can confirm order / direction before
/// printing.
final class BookletThumbnailer: SuperLog, @unchecked Sendable {

    // MARK: - Identity

    nonisolated static let emoji = "🖼️"
    nonisolated static let verbose: Bool = false
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.booklet-maker.thumbnailer"
    )

    // MARK: - Public types

    /// A single rendered thumbnail.
    struct Thumbnail: Equatable, Sendable {
        let sheetIndex: Int   // 0-based
        let fileURL: URL      // PNG on disk
    }

    // MARK: - Init

    init() {}

    // MARK: - API

    /// Render the first `count` sheets of `pdfURL` to PNG thumbnails
    /// in `outputDirectory`. Returns whatever was successfully rendered.
    func makeThumbnails(fromPDF pdfURL: URL,
                        count: Int = 5,
                        maxPixelWidth: CGFloat = 220,
                        outputDirectory: URL) async -> [Thumbnail] {
        await Task.detached(priority: .utility) {
            Self.runRendering(pdfURL: pdfURL,
                              count: count,
                              maxPixelWidth: maxPixelWidth,
                              outputDirectory: outputDirectory)
        }.value
    }

    // MARK: - Pipeline

    private static func runRendering(pdfURL: URL,
                                     count: Int,
                                     maxPixelWidth: CGFloat,
                                     outputDirectory: URL) -> [Thumbnail] {
        guard let document = PDFDocument(url: pdfURL) else {
            Self.logger.error("\(Self.t)Cannot open PDF for thumbnails: \(pdfURL.lastPathComponent)")
            return []
        }
        let total = min(count, document.pageCount)
        guard total > 0 else { return [] }

        do {
            try FileManager.default.createDirectory(
                at: outputDirectory, withIntermediateDirectories: true)
        } catch {
            Self.logger.error("\(Self.t)Cannot create thumbnail dir: \(error.localizedDescription)")
            return []
        }

        var results: [Thumbnail] = []
        results.reserveCapacity(total)

        for i in 0..<total {
            guard let page = document.page(at: i) else { continue }
            let pageRect = page.bounds(for: .cropBox)
            guard pageRect.width > 0, pageRect.height > 0 else { continue }

            let scale = maxPixelWidth / pageRect.width
            let pixelSize = NSSize(width: maxPixelWidth,
                                   height: pageRect.height * scale)

            let image = NSImage(size: pixelSize)
            image.lockFocus()
            if let ctx = NSGraphicsContext.current?.cgContext {
                ctx.setFillColor(.white)
                ctx.fill(CGRect(origin: .zero, size: pixelSize))
                ctx.saveGState()
                ctx.scaleBy(x: scale, y: scale)
                ctx.translateBy(x: -pageRect.minX, y: -pageRect.minY)
                page.draw(with: .cropBox, to: ctx)
                ctx.restoreGState()
            }
            image.unlockFocus()

            guard let tiff = image.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff),
                  let png = rep.representation(using: .png, properties: [:]) else {
                continue
            }

            let fileURL = outputDirectory
                .appendingPathComponent("thumbnail-\(i).png")
            do {
                try png.write(to: fileURL, options: .atomic)
                results.append(Thumbnail(sheetIndex: i, fileURL: fileURL))
            } catch {
                Self.logger.error("\(Self.t)Failed to write thumbnail: \(error.localizedDescription)")
            }
        }
        return results
    }
}
