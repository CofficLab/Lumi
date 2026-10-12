import SwiftUI

public enum EditorMultiCursorHighlightKind {
    case secondaryCaret
    case secondarySelection
}

public struct EditorMultiCursorHighlight: Identifiable {
    public let kind: EditorMultiCursorHighlightKind
    public let rect: CGRect

    public var id: String {
        "\(kind)-\(rect.minX)-\(rect.minY)-\(rect.width)-\(rect.height)"
    }

    public var fillColor: Color {
        switch kind {
        case .secondaryCaret:
            return Color.accentColor.opacity(0.95)
        case .secondarySelection:
            return Color.accentColor.opacity(0.14)
        }
    }

    public var strokeColor: Color {
        switch kind {
        case .secondaryCaret:
            return Color.accentColor
        case .secondarySelection:
            return Color.accentColor.opacity(0.55)
        }
    }

    public var lineWidth: CGFloat {
        switch kind {
        case .secondaryCaret:
            return 0
        case .secondarySelection:
            return 1
        }
    }

    public var dash: [CGFloat] {
        switch kind {
        case .secondaryCaret:
            return []
        case .secondarySelection:
            return [4, 3]
        }
    }

    public var cornerRadius: CGFloat {
        switch kind {
        case .secondaryCaret:
            return 1
        case .secondarySelection:
            return 3
        }
    }
}
