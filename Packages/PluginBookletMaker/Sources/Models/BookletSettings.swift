import CoreGraphics
import Foundation

// MARK: - Booklet Settings

/// User-tunable parameters that drive the imposition pipeline.
///
/// `BookletSettings` is a plain value type with a stable `Codable`
/// representation so that presets can be added later without breaking
/// persisted state.
struct BookletSettings: Codable, Equatable, Sendable {

    /// Output paper size.
    var outputPaper: PaperSize = .a4

    /// How source pages map onto output sheets.
    var layout: LayoutMode = .bookletFold

    /// Reading order. MVP only honours ``ReadingOrder/leftToRight``.
    var readingOrder: ReadingOrder = .leftToRight

    /// Outer margin (all four sides) in millimetres.
    var marginMM: Double = 5

    /// Inner gutter between the two source pages in millimetres.
    var gutterMM: Double = 5

    /// When `true` an odd-page source is padded with one blank page so the
    /// number of source pages becomes even.
    var padBlankPage: Bool = true

    /// When `true`, the renderer draws small tick marks at the corners of
    /// each page cell to aid trimming after printing.
    var addCutMarks: Bool = true

    // MARK: - Derived geometry

    /// Width of a single source page cell on the landscape output sheet, in points.
    func cellWidthInPoints() -> CGFloat {
        let paperWidth = PaperSize.mmToPt(outputPaper.heightMM)
        let margin    = PaperSize.mmToPt(marginMM)
        let gutter    = PaperSize.mmToPt(gutterMM)
        return (paperWidth - 2 * margin - gutter) / 2
    }

    /// Height of a single source page cell on the landscape output sheet, in points.
    func cellHeightInPoints() -> CGFloat {
        let paperHeight = PaperSize.mmToPt(outputPaper.widthMM)
        let margin      = PaperSize.mmToPt(marginMM)
        return paperHeight - 2 * margin
    }

    /// Origin of the left cell on the output sheet, in points.
    func leftCellOrigin() -> CGPoint {
        let margin = PaperSize.mmToPt(marginMM)
        return CGPoint(x: margin, y: margin)
    }

    /// Origin of the right cell on the output sheet, in points.
    func rightCellOrigin() -> CGPoint {
        let margin = PaperSize.mmToPt(marginMM)
        let gutter = PaperSize.mmToPt(gutterMM)
        return CGPoint(x: margin + cellWidthInPoints() + gutter,
                       y: margin)
    }
}
