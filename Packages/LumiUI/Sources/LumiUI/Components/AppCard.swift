import SwiftUI

public struct AppCard<Content: View>: View {
    public enum Style {
        case elevated
        case subtle
    }

    let style: Style
    let padding: EdgeInsets
    @LumiTheme private var theme
    @ViewBuilder let content: Content

    public init(
        style: Style = .elevated,
        padding: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .background(background)
            .overlay(border)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var background: some View {
        Group {
            switch style {
            case .elevated:
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Material.regularMaterial)
            case .subtle:
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(theme.textSecondary.opacity(0.06))
            }
        }
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(theme.textTertiary.opacity(style == .elevated ? 0.12 : 0.06), lineWidth: 1)
    }
}
