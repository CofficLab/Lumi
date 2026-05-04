import SwiftUI

/// 通用卡片容器：统一常见信息块样式。
struct AppCard<Content: View>: View {
    enum Style {
        case elevated
        case subtle
    }

    let style: Style
    let padding: EdgeInsets
    @EnvironmentObject private var themeVM: ThemeVM
    @ViewBuilder let content: Content

    init(
        style: Style = .elevated,
        padding: EdgeInsets = DesignTokens.Spacing.cardPadding,
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(background)
            .overlay(border)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous))
    }

    private var background: some View {
        let theme = themeVM.activeAppTheme
        return Group {
            switch style {
            case .elevated:
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                    .fill(DesignTokens.Material.glass)
            case .subtle:
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                    .fill(theme.workspaceSecondaryTextColor().opacity(0.06))
            }
        }
    }

    private var border: some View {
        let theme = themeVM.activeAppTheme
        return RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
            .stroke(theme.workspaceTertiaryTextColor().opacity(style == .elevated ? 0.12 : 0.06), lineWidth: 1)
    }
}

#Preview {
    VStack(spacing: 12) {
        AppCard(style: .elevated) {
            Text("Elevated Card")
        }
        AppCard(style: .subtle) {
            Text("Subtle Card")
        }
    }
    .padding()
    .inRootView()
}
