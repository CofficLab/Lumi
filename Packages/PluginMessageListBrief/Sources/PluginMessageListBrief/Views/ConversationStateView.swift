import LumiUI
import SwiftUI

/// 消息列表尾部的当前对话状态视图。
struct ConversationStateView: View {
    @ObservedObject private var stateVM: ConversationStateVM

    @LumiTheme private var theme

    init(stateVM: ConversationStateVM) {
        _stateVM = ObservedObject(wrappedValue: stateVM)
    }

    var body: some View {
        if let activity = stateVM.activity {
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
}
