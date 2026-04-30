import SwiftUI

enum EditorMultiCursorHighlightKind {
    case secondaryCaret
    case secondarySelection
}

struct EditorMultiCursorHighlight: Identifiable {
    let kind: EditorMultiCursorHighlightKind
    let rect: CGRect

    var id: String {
        "\(kind)-\(rect.minX)-\(rect.minY)-\(rect.width)-\(rect.height)"
    }

    var fillColor: Color {
        switch kind {
        case .secondaryCaret:
            return AppUI.Color.semantic.primary.opacity(0.95)
        case .secondarySelection:
            return AppUI.Color.semantic.primary.opacity(0.14)
        }
    }

    var strokeColor: Color {
        switch kind {
        case .secondaryCaret:
            return AppUI.Color.semantic.primary
        case .secondarySelection:
            return AppUI.Color.semantic.primary.opacity(0.55)
        }
    }

    var lineWidth: CGFloat {
        switch kind {
        case .secondaryCaret:
            return 0
        case .secondarySelection:
            return 1
        }
    }

    var dash: [CGFloat] {
        switch kind {
        case .secondaryCaret:
            return []
        case .secondarySelection:
            return [4, 3]
        }
    }

    var cornerRadius: CGFloat {
        switch kind {
        case .secondaryCaret:
            return 1
        case .secondarySelection:
            return 3
        }
    }
}
