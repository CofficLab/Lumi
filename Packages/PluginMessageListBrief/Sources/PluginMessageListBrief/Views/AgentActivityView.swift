import LumiUI
import SwiftUI

/// Brief 模式当前 Agent 活动的专用视图。
///
/// 这是实时状态展示，不是消息时间线的一部分，因此不会渲染 reasoning
/// 正文或工具原始输出。
struct AgentActivityView: View {
    @LumiTheme private var theme

    let activity: AgentActivityProjection

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            ProgressView()
                .controlSize(.small)
                .tint(theme.primary)

            Image(systemName: activity.phase.iconName)
                .font(.appCaptionEmphasized)
                .foregroundColor(theme.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text(activity.title)
                    .font(.appCaption)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)

                if let detail = activity.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.appMicro)
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            theme.primary.opacity(0.07),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.primary.opacity(0.16), lineWidth: 0.5)
        )
    }
}
