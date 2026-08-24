import CoreGraphics
import Foundation

// MARK: - Booklet Layout Engine

/// Pure, dependency-free imposition logic.
///
/// Everything in this enum is a static function so it can be exercised
/// directly from unit tests without instantiating any service object.
enum BookletLayoutEngine {

    // MARK: - Padding

    /// Return the number of source-page slots required by a layout.
    ///
    /// A duplex booklet always occupies four page slots per physical sheet,
    /// so booklet-fold input is padded to a multiple of four. Simple-pair
    /// layout retains its optional even-page padding behaviour.
    static func paddedInputCount(_ rawCount: Int,
                                 layout: LayoutMode,
                                 pad: Bool) -> Int {
        guard rawCount > 0 else { return 0 }
        switch layout {
        case .bookletFold:
            return ((rawCount + 3) / 4) * 4
        case .simplePair:
            guard pad else { return rawCount }
            return rawCount + (rawCount.isMultiple(of: 2) ? 0 : 1)
        }
    }

    // MARK: - Counts

    /// Number of PDF pages / print sides produced for a padded input count.
    static func outputSideCount(forPaddedInputCount n: Int) -> Int {
        guard n > 0 else { return 0 }
        return (n + 1) / 2
    }

    /// Number of physical sheets required for duplex booklet printing.
    static func physicalSheetCount(forPaddedInputCount n: Int) -> Int {
        guard n > 0 else { return 0 }
        return (n + 3) / 4
    }

    // MARK: - Mapping (booklet fold)

    /// Return the (left, right) source page numbers (1-based, 0 = blank)
    /// for the given `outputIndex` (0-based) under booklet-fold layout.
    ///
    /// Output sides are ordered front, back, front, back so ordinary duplex
    /// printing keeps the two sides of each physical sheet adjacent.
    /// Examples (input padded to a multiple of four):
    /// - N = 4  → [4,1] [2,3]
    /// - N = 8  → [8,1] [2,7] [6,3] [4,5]
    static func bookletFoldMapping(outputIndex: Int,
                                   paddedInputCount n: Int) -> (left: Int, right: Int) {
        let physicalSheetIndex = outputIndex / 2
        if outputIndex.isMultiple(of: 2) {
            return (n - 2 * physicalSheetIndex,
                    1 + 2 * physicalSheetIndex)
        }
        return (2 + 2 * physicalSheetIndex,
                n - 1 - 2 * physicalSheetIndex)
    }

    // MARK: - Mapping (simple pair)

    /// Return the (left, right) source page numbers (1-based, 0 = blank)
    /// for the given `outputIndex` (0-based) under simple-pair layout.
    static func simplePairMapping(outputIndex: Int,
                                  paddedInputCount n: Int) -> (left: Int, right: Int) {
        let left  = 2 * outputIndex + 1
        let right = left + 1
        let l = left  <= n ? left  : 0
        let r = right <= n ? right : 0
        return (l, r)
    }

    // MARK: - High-level

    /// Build the full sequence of output PDF pages / print sides.
    static func buildOutputSides(inputPageCount: Int,
                                 settings: BookletSettings) -> [OutputSheet] {
        let padded = paddedInputCount(inputPageCount,
                                      layout: settings.layout,
                                      pad: settings.padBlankPage)
        let total = outputSideCount(forPaddedInputCount: padded)
        guard total > 0 else { return [] }

        return (0..<total).map { idx in
            let pair: (Int, Int)
            switch settings.layout {
            case .bookletFold:
                pair = bookletFoldMapping(outputIndex: idx,
                                          paddedInputCount: padded)
            case .simplePair:
                pair = simplePairMapping(outputIndex: idx,
                                         paddedInputCount: padded)
            }
            let physicalSheetIndex: Int
            let side: OutputSheet.Side
            switch settings.layout {
            case .bookletFold:
                physicalSheetIndex = idx / 2
                side = idx.isMultiple(of: 2) ? .front : .back
            case .simplePair:
                physicalSheetIndex = idx
                side = .front
            }
            return OutputSheet(index: idx,
                               physicalSheetIndex: physicalSheetIndex,
                               side: side,
                               leftPage: pair.0 <= inputPageCount ? pair.0 : 0,
                               rightPage: pair.1 <= inputPageCount ? pair.1 : 0)
        }
    }

    /// Group output sides by the physical pieces of paper they belong to.
    static func buildPhysicalSheets(inputPageCount: Int,
                                    settings: BookletSettings) -> [PhysicalSheet] {
        let sides = buildOutputSides(inputPageCount: inputPageCount,
                                     settings: settings)
        let grouped = Dictionary(grouping: sides, by: \.physicalSheetIndex)
        return grouped.keys
            .sorted()
            .compactMap { index in
                guard let groupedSides = grouped[index],
                      let front = groupedSides.first(where: { $0.side == .front }) else {
                    return nil
                }
                return PhysicalSheet(
                    index: index,
                    front: front,
                    back: groupedSides.first(where: { $0.side == .back })
                )
            }
    }

    // MARK: - Cell rects (helpers for the renderer)

    /// Rect (in output points) of the left page cell.
    static func leftRect(for settings: BookletSettings) -> CGRect {
        CGRect(origin: settings.leftCellOrigin(),
               size: CGSize(width: settings.cellWidthInPoints(),
                            height: settings.cellHeightInPoints()))
    }

    /// Rect (in output points) of the right page cell.
    static func rightRect(for settings: BookletSettings) -> CGRect {
        CGRect(origin: settings.rightCellOrigin(),
               size: CGSize(width: settings.cellWidthInPoints(),
                            height: settings.cellHeightInPoints()))
    }

    /// Return a rect that preserves the source page's aspect ratio and
    /// centres it inside `target`. The aspect ratio is `width / height`.
    static func fitRect(aspectRatio: CGFloat, into target: CGRect) -> CGRect {
        guard target.width > 0, target.height > 0, aspectRatio > 0 else {
            return target
        }
        let cellAspect = target.width / target.height
        let size: CGSize
        if aspectRatio >= cellAspect {
            // Source is wider (or equal) → fit by height.
            let h = target.height
            let w = h * aspectRatio
            size = CGSize(width: w, height: h)
        } else {
            // Source is taller → fit by width.
            let w = target.width
            let h = w / aspectRatio
            size = CGSize(width: w, height: h)
        }
        let origin = CGPoint(x: target.midX - size.width  / 2,
                             y: target.midY - size.height / 2)
        return CGRect(origin: origin, size: size)
    }
}
