import CoreGraphics
import Foundation

// MARK: - Booklet Layout Engine

/// Pure, dependency-free imposition logic.
///
/// Everything in this enum is a static function so it can be exercised
/// directly from unit tests without instantiating any service object.
enum BookletLayoutEngine {

    // MARK: - Padding

    /// Return the source page count padded to an even number.
    ///
    /// If `pad` is `true` and the input is already even, the value is
    /// returned unchanged. When the input is odd, one blank slot is
    /// appended.
    static func padInputCount(_ rawCount: Int, pad: Bool) -> Int {
        guard pad else { return rawCount }
        return rawCount + (rawCount.isMultiple(of: 2) ? 0 : 1)
    }

    // MARK: - Sheet count

    /// Number of output sheets produced for a (possibly padded) source
    /// page count.
    static func sheetCount(forPaddedInputCount n: Int) -> Int {
        guard n > 0 else { return 0 }
        return (n + 1) / 2
    }

    // MARK: - Mapping (booklet fold)

    /// Return the (left, right) source page numbers (1-based, 0 = blank)
    /// for the given `outputIndex` (0-based) under booklet-fold layout.
    ///
    /// Examples (input already padded to even):
    /// - N = 4  → [1,4] [2,3]
    /// - N = 6  → [1,6] [2,5] [3,4]
    /// - N = 8  → [1,8] [2,7] [3,6] [4,5]
    static func bookletFoldMapping(outputIndex: Int,
                                   paddedInputCount n: Int) -> (left: Int, right: Int) {
        let k = outputIndex + 1
        let left  = min(k, n - k + 1)
        let right = max(k, n - k + 1)
        return (left, right)
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

    /// Build the full sequence of output sheets for a given source page
    /// count and settings.
    static func buildSheets(inputPageCount: Int,
                            settings: BookletSettings) -> [OutputSheet] {
        let padded = padInputCount(inputPageCount, pad: settings.padBlankPage)
        let total  = sheetCount(forPaddedInputCount: padded)
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
            return OutputSheet(index: idx,
                               leftPage:  pair.0,
                               rightPage: pair.1)
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
