import CoreGraphics
import Foundation

/// User-tunable parameters used by the booklet planner.
public struct BookletSettings: Codable, Equatable, Sendable {
    public var outputPaper: PaperSize
    public var layout: LayoutMode
    public var signaturePageCount: Int
    public var readingOrder: ReadingOrder
    public var marginMM: Double
    public var gutterMM: Double
    public var padBlankPage: Bool
    public var addCutMarks: Bool

    public static let signaturePageCountOptions = [4, 8, 12, 16, 24, 32]

    public init(
        outputPaper: PaperSize = .a4,
        layout: LayoutMode = .bookletFold,
        signaturePageCount: Int = 4,
        readingOrder: ReadingOrder = .leftToRight,
        marginMM: Double = 5,
        gutterMM: Double = 5,
        padBlankPage: Bool = true,
        addCutMarks: Bool = true
    ) {
        self.outputPaper = outputPaper
        self.layout = layout
        self.signaturePageCount = signaturePageCount
        self.readingOrder = readingOrder
        self.marginMM = marginMM
        self.gutterMM = gutterMM
        self.padBlankPage = padBlankPage
        self.addCutMarks = addCutMarks
    }

    public func cellWidthInPoints() -> CGFloat {
        let paperWidth = PaperSize.mmToPt(outputPaper.heightMM)
        let margin = PaperSize.mmToPt(marginMM)
        let gutter = PaperSize.mmToPt(gutterMM)
        return (paperWidth - 2 * margin - gutter) / 2
    }

    public func cellHeightInPoints() -> CGFloat {
        let paperHeight = PaperSize.mmToPt(outputPaper.widthMM)
        let margin = PaperSize.mmToPt(marginMM)
        return paperHeight - 2 * margin
    }

    public func leftCellOrigin() -> CGPoint {
        let margin = PaperSize.mmToPt(marginMM)
        return CGPoint(x: margin, y: margin)
    }

    public func rightCellOrigin() -> CGPoint {
        let margin = PaperSize.mmToPt(marginMM)
        let gutter = PaperSize.mmToPt(gutterMM)
        return CGPoint(x: margin + cellWidthInPoints() + gutter, y: margin)
    }
}
