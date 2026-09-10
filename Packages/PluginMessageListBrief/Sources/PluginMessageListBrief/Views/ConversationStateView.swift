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
                Image(systemName: activity.phase.iconName)
                    .font(.appCaptionEmphasized)
                    .foregroundColor(theme.primary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(activity.title)
                        .font(.appCaption)
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)

                    Text(activity.detail ?? " ")
                        .font(.appMicro)
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(1)
                        .opacity(activity.detail?.isEmpty == false ? 1 : 0)
                }
                .frame(height: 30, alignment: .leading)

                Spacer(minLength: 0)

                ProgressView()
                    .controlSize(.small)
                    .tint(theme.primary)
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
            .frame(height: 46)
        }
    }
}
