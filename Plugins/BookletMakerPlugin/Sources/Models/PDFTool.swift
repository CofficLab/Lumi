import Foundation

/// A workspace tool that operates on the shared current PDF document.
enum PDFTool: String, CaseIterable, Identifiable {
    case booklet
    case split

    var id: String { rawValue }

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
