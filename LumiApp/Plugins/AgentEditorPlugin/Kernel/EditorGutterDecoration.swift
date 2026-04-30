import SwiftUI
import LanguageServerProtocol

@MainActor
struct EditorGutterDecorationContext {
    let languageId: String
    let currentLine: Int
    let visibleLineRange: Range<Int>
    let renderLineRange: Range<Int>
    let isLargeFileMode: Bool
}

enum EditorGutterDecorationTone {
    case neutral
    case accent
    case info
    case success
    case warning
    case error
}

enum EditorGitDecorationChangeKind {
    case added
    case modified
    case deleted
}

enum EditorGutterDecorationKind {
    case diagnostic(EditorStatusLevel)
    case gitChange(EditorGitDecorationChangeKind)
    case symbol(SymbolKind)
    case custom(name: String, tone: EditorGutterDecorationTone, symbolName: String?)
}

struct EditorGutterDecorationSuggestion: Identifiable {
    let id: String
    let line: Int
    let lane: Int
    let kind: EditorGutterDecorationKind
    let priority: Int
    let badgeText: String?

    init(
        id: String,
        line: Int,
        lane: Int = 0,
        kind: EditorGutterDecorationKind,
        priority: Int = 0,
        badgeText: String? = nil
    ) {
        self.id = id
        self.line = line
        self.lane = lane
        self.kind = kind
        self.priority = priority
        self.badgeText = badgeText
    }
}

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
                fillColor: AppUI.Color.semantic.error,
                strokeColor: AppUI.Color.semantic.error.opacity(0.55),
                foregroundColor: SwiftUI.Color.white,
                shape: .circle,
                size: CGSize(width: size, height: size),
                cornerRadius: size / 2
            )
        case .diagnostic(.warning):
            return EditorGutterDecorationResolvedStyle(
                fillColor: AppUI.Color.semantic.warning,
                strokeColor: AppUI.Color.semantic.warning.opacity(0.55),
                foregroundColor: SwiftUI.Color.white,
                shape: .circle,
                size: CGSize(width: size, height: size),
                cornerRadius: size / 2
            )
        case .diagnostic:
            return EditorGutterDecorationResolvedStyle(
                fillColor: AppUI.Color.semantic.info,
                strokeColor: AppUI.Color.semantic.info.opacity(0.55),
                foregroundColor: SwiftUI.Color.white,
                shape: .circle,
                size: CGSize(width: size, height: size),
                cornerRadius: size / 2
            )
        case .gitChange(let change):
            let tone: SwiftUI.Color
            switch change {
            case .added:
                tone = AppUI.Color.semantic.success
            case .modified:
                tone = AppUI.Color.semantic.info
            case .deleted:
                tone = AppUI.Color.semantic.error
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
                tint = AppUI.Color.semantic.primary
            case .function, .method, .constructor:
                tint = AppUI.Color.semantic.success
            default:
                tint = AppUI.Color.semantic.textSecondary
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
                tint = AppUI.Color.semantic.textSecondary
            case .accent:
                tint = AppUI.Color.semantic.primary
            case .info:
                tint = AppUI.Color.semantic.info
            case .success:
                tint = AppUI.Color.semantic.success
            case .warning:
                tint = AppUI.Color.semantic.warning
            case .error:
                tint = AppUI.Color.semantic.error
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
