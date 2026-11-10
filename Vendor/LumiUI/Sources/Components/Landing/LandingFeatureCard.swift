import SwiftUI

/// 落地页特性卡片:图标渐变徽标 + 标题 + 描述,悬停时轻微抬升并高亮边框。
///
/// 既可单独使用,也可作为 `LandingFeatureGrid` 的格子。
public struct LandingFeatureCard: View {
    @LumiTheme private var theme
    @LumiMotionPreferenceReader private var motionPreference

    private let icon: String
    private let tint: Color?
    private let title: String
    private let description: String

    /// 卡片强调色。默认跟随主题 `primary`。
    private var accent: Color { tint ?? theme.primary }

    @State private var isHovering = false

    public init(icon: String, tint: Color? = nil, title: String, description: String) {
        self.icon = icon
        self.tint = tint
        self.title = title
        self.description = description
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(accent.opacity(0.14))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.appBodyEmphasized)
                    .foregroundColor(theme.textPrimary)

                Text(description)
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isHovering ? theme.appListRowHoverBackground : theme.textSecondary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isHovering ? theme.appHoverBorder : theme.appSubtleBorder, lineWidth: 1)
        )
        .scaleEffect(isHovering && motionPreference.allowsMotion ? LumiMotion.hoverScale : 1.0)
        .animation(LumiMotion.enabled(LumiMotion.hover, preference: motionPreference), value: isHovering)
        .onHover { hovering in
            LumiMotion.animate(LumiMotion.enabled(LumiMotion.hover, preference: motionPreference)) {
                isHovering = hovering
            }
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        LandingFeatureCard(icon: "terminal", tint: .blue, title: "多标签终端", description: "并行执行多个命令会话,各自独立。")
        LandingFeatureCard(icon: "paintbrush", tint: .purple, title: "主题同步", description: "自动跟随编辑器主题。")
    }
    .padding()
    .frame(width: 360)
}
