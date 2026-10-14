import BookletMakerCore

extension PDFSplitSegment {
    /// Localized presentation kept in the host plugin; the shared core only
    /// owns the range data and remains independent from Lumi localization.
    var rangeLabel: String {
        if startPage == endPage {
            return BookletLocalization.string("Page %lld", Int64(startPage))
        }
        return BookletLocalization.string(
            "Pages %lld–%lld",
            Int64(startPage),
            Int64(endPage)
        )
    }
}
