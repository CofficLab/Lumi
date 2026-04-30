import SwiftUI

enum EditorInlinePresentationKind {
    case message(EditorStatusLevel)
    case value
    case diff
}

struct EditorInlinePresentation: Identifiable {
    let id: String
    let kind: EditorInlinePresentationKind
    let origin: CGPoint
    let size: CGSize
    let iconName: String
    let title: String
    let detail: String?
    let badgeText: String?
    let style: EditorInlinePresentationResolvedStyle
}

struct EditorInlinePresentationResolvedStyle {
    let backgroundColor: Color
    let borderColor: Color
    let foregroundColor: Color
    let accentColor: Color
}

struct EditorInlinePresentationStyle {
    let cornerRadius: CGFloat
    let borderWidth: CGFloat
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let lineGap: CGFloat
    let inlineGap: CGFloat
    let outerPadding: CGFloat
    let maxWidth: CGFloat

    static let standard = EditorInlinePresentationStyle(
        cornerRadius: 8,
        borderWidth: 1,
        horizontalPadding: 8,
        verticalPadding: 5,
        lineGap: 6,
        inlineGap: 8,
        outerPadding: 8,
        maxWidth: 280
    )

    func resolvedStyle(for kind: EditorInlinePresentationKind) -> EditorInlinePresentationResolvedStyle {
        switch kind {
        case .message(.error):
            return EditorInlinePresentationResolvedStyle(
                backgroundColor: AppUI.Color.semantic.error.opacity(0.12),
                borderColor: AppUI.Color.semantic.error.opacity(0.34),
                foregroundColor: AppUI.Color.semantic.textPrimary,
                accentColor: AppUI.Color.semantic.error
            )
        case .message(.warning):
            return EditorInlinePresentationResolvedStyle(
                backgroundColor: AppUI.Color.semantic.warning.opacity(0.14),
                borderColor: AppUI.Color.semantic.warning.opacity(0.34),
                foregroundColor: AppUI.Color.semantic.textPrimary,
                accentColor: AppUI.Color.semantic.warning
            )
        case .message:
            return EditorInlinePresentationResolvedStyle(
                backgroundColor: AppUI.Color.semantic.primary.opacity(0.12),
                borderColor: AppUI.Color.semantic.primary.opacity(0.28),
                foregroundColor: AppUI.Color.semantic.textPrimary,
                accentColor: AppUI.Color.semantic.primary
            )
        case .value:
            return EditorInlinePresentationResolvedStyle(
                backgroundColor: AppUI.Color.semantic.textPrimary.opacity(0.06),
                borderColor: AppUI.Color.semantic.textTertiary.opacity(0.22),
                foregroundColor: AppUI.Color.semantic.textSecondary,
                accentColor: AppUI.Color.semantic.textSecondary
            )
        case .diff:
            return EditorInlinePresentationResolvedStyle(
                backgroundColor: AppUI.Color.semantic.success.opacity(0.12),
                borderColor: AppUI.Color.semantic.success.opacity(0.3),
                foregroundColor: AppUI.Color.semantic.textPrimary,
                accentColor: AppUI.Color.semantic.success
            )
        }
    }
}
