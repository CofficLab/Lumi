import Foundation

// MARK: - Output print side

/// Describes how one side of a physical output sheet is filled.
///
/// `leftPage` / `rightPage` use **1-based** indexing into the (possibly
/// padded) source page sequence. A value of `0` means "render blank".
struct OutputSheet: Equatable, Sendable {
    enum Side: String, Equatable, Sendable {
        case front
        case back
    }

    /// 0-based page index of this print side in the output PDF.
    let index: Int

    /// 0-based index of the physical sheet carrying this print side.
    let physicalSheetIndex: Int

    /// Whether this is the front or back of the physical sheet.
    let side: Side

    /// 1-based source page rendered on the left, or 0 for blank.
    let leftPage: Int

    /// 1-based source page rendered on the right, or 0 for blank.
    let rightPage: Int

    static func blank(index: Int,
                      physicalSheetIndex: Int,
                      side: Side) -> OutputSheet {
        OutputSheet(index: index,
                    physicalSheetIndex: physicalSheetIndex,
                    side: side,
                    leftPage: 0,
                    rightPage: 0)
    }
}

// MARK: - Physical sheet

/// A physical piece of paper, with one or two printable sides.
struct PhysicalSheet: Equatable, Sendable {
    let index: Int
    let front: OutputSheet
    let back: OutputSheet?

    var outputSides: [OutputSheet] {
        if let back { return [front, back] }
        return [front]
    }
}
