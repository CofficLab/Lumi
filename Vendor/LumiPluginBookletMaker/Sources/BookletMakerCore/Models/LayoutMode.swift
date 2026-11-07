import Foundation

/// How source pages are arranged on printable output sheets.
public enum LayoutMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case simplePair
    case bookletFold
    case signatureFold

    public var id: String { rawValue }

    /// Stable English fallback. Hosts may provide localized presentation text.
    public var displayName: String {
        switch self {
        case .simplePair: "Simple Pair"
        case .bookletFold: "Booklet Fold"
        case .signatureFold: "Sectioned Booklet"
        }
    }

    public var isFolded: Bool { self != .simplePair }
}

/// Reading order used by the booklet planner.
public enum ReadingOrder: String, CaseIterable, Identifiable, Codable, Sendable {
    case leftToRight

    public var id: String { rawValue }
}
