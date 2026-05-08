import SwiftUI

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
                backgroundColor: Color.red.opacity(0.12),
                borderColor: Color.red.opacity(0.34),
                foregroundColor: Color.primary,
                accentColor: .red
            )
        case .message(.warning):
            return EditorInlinePresentationResolvedStyle(
                backgroundColor: Color.orange.opacity(0.14),
                borderColor: Color.orange.opacity(0.34),
                foregroundColor: Color.primary,
                accentColor: .orange
            )
        case .message:
            return EditorInlinePresentationResolvedStyle(
                backgroundColor: Color.accentColor.opacity(0.12),
                borderColor: Color.accentColor.opacity(0.28),
                foregroundColor: Color.primary,
                accentColor: Color.accentColor
            )
        case .value:
            return EditorInlinePresentationResolvedStyle(
                backgroundColor: Color.primary.opacity(0.06),
                borderColor: Color.secondary.opacity(0.22),
                foregroundColor: Color.secondary,
                accentColor: Color.secondary
            )
        case .diff:
            return EditorInlinePresentationResolvedStyle(
                backgroundColor: Color.green.opacity(0.12),
                borderColor: Color.green.opacity(0.3),
                foregroundColor: Color.primary,
                accentColor: .green
            )
        }
    }
}
