import SwiftUI
import LanguageServerProtocol

struct EditorGutterDecoration: Identifiable {
    let id: String
    let line: Int
    let lane: Int
    let kind: EditorGutterDecorationKind
    let rect: CGRect
    let style: EditorGutterDecorationResolvedStyle
    let badgeText: String?
    let symbolName: String?
}

enum EditorGutterDecorationShape {
    case circle
    case roundedRect
    case bar
}

struct EditorGutterDecorationResolvedStyle {
    let fillColor: SwiftUI.Color
    let strokeColor: SwiftUI.Color
    let foregroundColor: SwiftUI.Color
    let shape: EditorGutterDecorationShape
    let size: CGSize
    let cornerRadius: CGFloat
}

struct EditorGutterDecorationStyle {
    let laneSpacing: CGFloat
    let baseX: CGFloat
    let size: CGFloat
    let barWidth: CGFloat
    let outerPadding: CGFloat

    static let standard = EditorGutterDecorationStyle(
        laneSpacing: 11,
        baseX: 8,
        size: 9,
        barWidth: 3,
        outerPadding: 4
    )

    func resolvedStyle(for kind: EditorGutterDecorationKind) -> EditorGutterDecorationResolvedStyle {
        switch kind {
        case .diagnostic(.error):
            return EditorGutterDecorationResolvedStyle(
                fillColor: .red,
                strokeColor: Color.red.opacity(0.55),
                foregroundColor: SwiftUI.Color.white,
                shape: .circle,
                size: CGSize(width: size, height: size),
                cornerRadius: size / 2
            )
        case .diagnostic(.warning):
            return EditorGutterDecorationResolvedStyle(
                fillColor: .orange,
                strokeColor: Color.orange.opacity(0.55),
                foregroundColor: SwiftUI.Color.white,
                shape: .circle,
                size: CGSize(width: size, height: size),
                cornerRadius: size / 2
            )
        case .diagnostic:
            return EditorGutterDecorationResolvedStyle(
                fillColor: .blue,
                strokeColor: Color.blue.opacity(0.55),
                foregroundColor: SwiftUI.Color.white,
                shape: .circle,
                size: CGSize(width: size, height: size),
                cornerRadius: size / 2
            )
        case .gitChange(let change):
            let tone: SwiftUI.Color
            switch change {
            case .added:
                tone = .green
            case .modified:
                tone = .blue
            case .deleted:
                tone = .red
            }
            return EditorGutterDecorationResolvedStyle(
                fillColor: tone,
                strokeColor: tone.opacity(0.55),
                foregroundColor: SwiftUI.Color.white,
                shape: .bar,
                size: CGSize(width: barWidth, height: size + 3),
                cornerRadius: barWidth / 2
            )
        case .symbol(let kind):
            let tint: SwiftUI.Color
            switch kind {
            case .class, .struct, .interface, .enum, .namespace, .module:
                tint = Color.accentColor
            case .function, .method, .constructor:
                tint = .green
            default:
                tint = Color.secondary
            }
            return EditorGutterDecorationResolvedStyle(
                fillColor: tint.opacity(0.18),
                strokeColor: tint.opacity(0.38),
                foregroundColor: tint,
                shape: .roundedRect,
                size: CGSize(width: size + 3, height: size + 3),
                cornerRadius: 3
            )
        case .custom(_, let tone, _):
            let tint: SwiftUI.Color
            switch tone {
            case .neutral:
                tint = Color.secondary
            case .accent:
                tint = Color.accentColor
            case .info:
                tint = .blue
            case .success:
                tint = .green
            case .warning:
                tint = .orange
            case .error:
                tint = .red
            }
            return EditorGutterDecorationResolvedStyle(
                fillColor: tint.opacity(0.16),
                strokeColor: tint.opacity(0.38),
                foregroundColor: tint,
                shape: .roundedRect,
                size: CGSize(width: size + 3, height: size + 3),
                cornerRadius: 3
            )
        }
    }
}
