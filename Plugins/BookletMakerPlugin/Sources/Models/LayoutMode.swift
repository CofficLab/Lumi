import Foundation

// MARK: - Layout Mode

/// How pages from the source PDF are arranged onto the output sheet.
///
/// Two values are supported in MVP:
///
/// - ``simplePair``: page `2k` sits next to page `2k+1`, in document order.
///   Useful when the user wants to print only the front side and then re-feed
///   the sheets manually for the back side.
///
/// - ``bookletFold``: pages are rearranged into imposition order so that after
///   A4 duplex printing, folding the sheets along the centre line and stapling
///   them produces a correctly ordered A5 booklet.
enum LayoutMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case simplePair
    case bookletFold

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .simplePair:  return "Simple Pair"
        case .bookletFold: return "Booklet Fold"
        }
    }
}

// MARK: - Reading Order

/// Reading order of the booklet. MVP only supports left-to-right; the enum
/// exists so the public surface does not need to change when right-to-left
/// is added in a later release.
enum ReadingOrder: String, CaseIterable, Identifiable, Codable, Sendable {
    case leftToRight
    // case rightToLeft   // reserved for v1.1

    var id: String { rawValue }
}
