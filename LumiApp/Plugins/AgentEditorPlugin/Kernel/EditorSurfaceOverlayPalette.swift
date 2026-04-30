import SwiftUI
import AppKit
import CodeEditSourceEditor

enum EditorSurfaceHighlightKind: Equatable {
    case currentLine
    case findMatch
    case currentMatch
    case bracketMatch
}

struct EditorSurfaceHighlightStyle {
    let fillColor: Color
    let strokeColor: Color
    let cornerRadius: CGFloat
    let lineWidth: CGFloat
    let minimumWidth: CGFloat
    let minimumHeight: CGFloat
    let zIndex: Double
}

struct EditorSurfaceHighlight: Identifiable {
    let kind: EditorSurfaceHighlightKind
    let rect: CGRect
    let style: EditorSurfaceHighlightStyle

    var id: String {
        "\(kind)-\(rect.minX)-\(rect.minY)-\(rect.width)-\(rect.height)"
    }
}

@MainActor
struct EditorSurfaceOverlayPalette {
    private let lineHighlight: NSColor
    private let selection: NSColor

    init(theme: EditorTheme?) {
        self.lineHighlight = theme?.lineHighlight ?? EditorThemeAdapter.fallbackTheme().lineHighlight
        self.selection = theme?.selection ?? EditorThemeAdapter.fallbackTheme().selection
    }

    func style(for kind: EditorSurfaceHighlightKind) -> EditorSurfaceHighlightStyle {
        switch kind {
        case .currentLine:
            return EditorSurfaceHighlightStyle(
                fillColor: Color(nsColor: lineHighlight.withAlphaComponent(0.7)),
                strokeColor: .clear,
                cornerRadius: 0,
                lineWidth: 0,
                minimumWidth: 0,
                minimumHeight: 2,
                zIndex: 0
            )

        case .findMatch:
            let accent = selection.blended(withFraction: 0.45, of: lineHighlight) ?? selection
            return EditorSurfaceHighlightStyle(
                fillColor: Color(nsColor: accent.withAlphaComponent(0.18)),
                strokeColor: Color(nsColor: accent.withAlphaComponent(0.38)),
                cornerRadius: 3,
                lineWidth: 0.5,
                minimumWidth: 2,
                minimumHeight: 2,
                zIndex: 1
            )

        case .currentMatch:
            return EditorSurfaceHighlightStyle(
                fillColor: Color(nsColor: selection.withAlphaComponent(0.58)),
                strokeColor: Color(nsColor: selection.withAlphaComponent(0.96)),
                cornerRadius: 4,
                lineWidth: 1,
                minimumWidth: 2,
                minimumHeight: 2,
                zIndex: 2
            )

        case .bracketMatch:
            let accent = selection.blended(withFraction: 0.35, of: lineHighlight) ?? selection
            return EditorSurfaceHighlightStyle(
                fillColor: Color(nsColor: accent.withAlphaComponent(0.34)),
                strokeColor: Color(nsColor: accent.withAlphaComponent(0.78)),
                cornerRadius: 2,
                lineWidth: 1,
                minimumWidth: 3,
                minimumHeight: 2,
                zIndex: 3
            )
        }
    }
}
