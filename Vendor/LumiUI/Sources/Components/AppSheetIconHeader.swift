import SwiftUI

/// Hero 图标页头：大圆渐变底 + 大图标，下方可选「小图标 + 标题」行。
///
/// 用于商店/购买确认等全页视觉头部（Cisum 贡献）。
public struct AppSheetIconHeader: View {
    @LumiTheme private var theme

    let systemImage: String
    let title: Text?
    let tint: Color

    public init(systemImage: String, title: LocalizedStringKey? = nil, tint: Color? = nil) {
        self.systemImage = systemImage
        self.title = title.map { Text($0) }
        self.tint = tint ?? .accentColor
    }

    public init(systemImage: String, title: String? = nil, tint: Color? = nil) {
        self.systemImage = systemImage
        self.title = title.map(Text.init)
        self.tint = tint ?? .accentColor
    }

    public var body: some View {
        VStack(spacing: AppUI.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.16), theme.primarySecondary.opacity(0.10)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: systemImage)
                    .font(.system(size: 58, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [tint, theme.primarySecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .frame(height: 120)

            if let title {
                HStack(spacing: AppUI.Spacing.sm) {
                    Image(systemName: systemImage)
                        .font(.title3)
                        .foregroundColor(tint)
                    title
                        .font(AppUI.Typography.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.textPrimary)
                    Spacer()
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        AppSheetIconHeader(systemImage: "giftcard.fill", title: nil as String?, tint: .blue)
        AppSheetIconHeader(systemImage: "arrow.counterclockwise", title: "Reset", tint: .orange)
    }
    .padding()
    .frame(width: 320)
}
