import SwiftUI

public struct EditorInlinePresentation: Identifiable {
    public let id: String
    public let kind: EditorInlinePresentationKind
    public let origin: CGPoint
    public let size: CGSize
    public let iconName: String
    public let title: String
    public let detail: String?
    public let badgeText: String?
    public let style: EditorInlinePresentationResolvedStyle
}

public struct EditorInlinePresentationResolvedStyle {
    public let backgroundColor: Color
    public let borderColor: Color
    public let foregroundColor: Color
    public let accentColor: Color
}

public struct EditorInlinePresentationStyle: Sendable {
    public let cornerRadius: CGFloat
    public let borderWidth: CGFloat
    public let horizontalPadding: CGFloat
    public let verticalPadding: CGFloat
    public let lineGap: CGFloat
    public let inlineGap: CGFloat
    public let outerPadding: CGFloat
    public let maxWidth: CGFloat

    public static let standard = EditorInlinePresentationStyle(
        cornerRadius: 8,
        borderWidth: 1,
        horizontalPadding: 8,
        verticalPadding: 5,
        lineGap: 6,
        inlineGap: 8,
        outerPadding: 8,
        maxWidth: 280
    )

    public func resolvedStyle(for kind: EditorInlinePresentationKind) -> EditorInlinePresentationResolvedStyle {
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
