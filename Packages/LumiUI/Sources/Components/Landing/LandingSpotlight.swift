import SwiftUI

/// 落地页的「签名特性」大块。
///
/// 比 `LandingFeatureCard` 更有视觉份量:柔和的强调色渐变底 + 大号图标徽标 +
/// 标题 + 较长的说明 + 可选的尾部内容(胶囊、迷你预览等)。适合用来突出
/// 某个插件最想强调的单一能力或核心产出,放在显眼位置。
public struct LandingSpotlight<Trailing: View>: View {
    @LumiTheme private var theme

    private let icon: String
    private let tint: Color?
    private let title: String
    private let message: String
    @ViewBuilder private let trailing: () -> Trailing

    private var accent: Color { tint ?? theme.primary }

    /// 创建签名特性块。
    public init(
        icon: String,
        tint: Color? = nil,
        title: String,
        message: String,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.icon = icon
        self.tint = tint
        self.title = title
        self.message = message
        self.trailing = trailing
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(colors: [accent, accent.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 52, height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(accent.opacity(0.14))
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                Text(message)
                    .font(.appCallout)
                    .foregroundColor(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                trailing()
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.10), theme.textSecondary.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(accent.opacity(0.22), lineWidth: 1)
        )
    }
}

public extension LandingSpotlight where Trailing == EmptyView {
    /// 不带尾部内容的签名特性块。
    init(icon: String, tint: Color? = nil, title: String, message: String) {
        self.init(icon: icon, tint: tint, title: title, message: message) { EmptyView() }
    }
}

#Preview {
    VStack(spacing: 12) {
        LandingSpotlight(
            icon: "wand.and.stars", tint: .purple,
            title: "AI 一键生成全套图标",
            message: "上传一张图,自动产出所有尺寸与圆角的应用图标。"
        )
        LandingSpotlight(
            icon: "chart.bar.fill", tint: .green,
            title: "贡献热力图",
            message: "把你的编码活动可视化为一张热力图。"
        ) {
            HStack(spacing: 6) {
                AppTag("365 天")
                AppTag("逐日统计")
            }
            .padding(.top, 2)
        }
    }
    .padding()
    .frame(width: 460)
}
