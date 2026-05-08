import SwiftUI

public struct AppTag: View {
    @LumiTheme private var theme

    public enum Style {
        case subtle
        case accent
    }

    let title: String
    let systemImage: String?
    let style: Style

    public init(
        _ title: String,
        systemImage: String? = nil,
        style: Style = .subtle
    ) {
        self.title = title
        self.systemImage = systemImage
        self.style = style
    }

    public var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .medium))
            }
            Text(title)
                .font(DesignTokens.Typography.caption2)
                .lineLimit(1)
        }
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    private var foregroundColor: Color {
        switch style {
        case .subtle:
            theme.textSecondary
        case .accent:
            theme.textPrimary
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .subtle:
            theme.textSecondary.opacity(0.10)
        case .accent:
            theme.primary.opacity(0.14)
        }
    }

    private var borderColor: Color {
        switch style {
        case .subtle:
            Color.white.opacity(0.06)
        case .accent:
            theme.primary.opacity(0.25)
        }
    }
}
