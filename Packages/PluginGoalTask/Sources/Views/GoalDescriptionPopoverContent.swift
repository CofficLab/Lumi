import LumiUI
import SwiftUI

/// Goal 描述的长文本弹窗内容。
///
/// 用于 SidebarHeader 中点击 info.circle 后的二级 popover,
/// 独立文件以便复用与单元预览。
struct GoalDescriptionPopoverContent: View {
    @LumiTheme private var theme

    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()
                .opacity(0.7)

            ScrollView {
                Text(text)
                    .font(.body)
                    .foregroundColor(theme.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(3)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
            .scrollIndicators(.automatic)
        }
        .frame(width: 360, height: 260)
        .background(theme.background)
        .appThemedAppearance()
        .background {
            ThemeWindowAppearanceBridge()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "text.alignleft")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(theme.primary)
                .frame(width: 28, height: 28)
                .background(
                    theme.primary.opacity(0.12),
                    in: Circle()
                )

            Text(LumiPluginLocalization.string("Goal description", bundle: .module))
                .font(.appCaptionEmphasized)
                .foregroundColor(theme.textPrimary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
