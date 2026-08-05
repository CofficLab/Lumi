import Foundation

// MARK: - Output Sheet

/// Describes how a single output sheet is filled.
///
/// `leftPage` / `rightPage` use **1-based** indexing into the (possibly
/// padded) source page sequence. A value of `0` means "render blank".
struct OutputSheet: Equatable, Sendable {
    /// 0-based index of this sheet in the output document.
    let index: Int

    /// 1-based source page rendered on the left, or 0 for blank.
    let leftPage: Int

    /// 1-based source page rendered on the right, or 0 for blank.
    let rightPage: Int

    static func blank(index: Int) -> OutputSheet {
        OutputSheet(index: index, leftPage: 0, rightPage: 0)
    }
}
