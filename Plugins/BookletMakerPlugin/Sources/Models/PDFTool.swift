import Foundation

/// A workspace tool that operates on the shared current PDF document.
enum PDFTool: String, CaseIterable, Identifiable {
    case booklet
    case split

    var id: String { rawValue }

    /// UI display order for the rail's tool picker.
    ///
    /// "Split PDF" is listed before "Booklet Maker" so the split
    /// entry sits above the booklet entry in the rail.
    static let displayOrder: [PDFTool] = [.split, .booklet]

    var title: String {
        switch self {
        case .booklet:
            BookletLocalization.string("Booklet Maker")
        case .split:
            BookletLocalization.string("Split PDF")
        }
    }

    var subtitle: String {
        switch self {
        case .booklet:
            BookletLocalization.string("Duplex imposition and binding")
        case .split:
            BookletLocalization.string("Split after specified pages")
        }
    }

    var systemImage: String {
        switch self {
        case .booklet: "book.closed"
        case .split: "scissors"
        }
    }
}
