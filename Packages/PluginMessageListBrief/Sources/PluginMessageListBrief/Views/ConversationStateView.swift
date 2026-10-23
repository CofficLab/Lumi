import LumiUI
import SwiftUI

/// 消息列表尾部的当前对话状态视图。
///
/// 状态卡恒为**一行**：标题与细节合并到同一行（`标题 · 细节`），没有细节时
/// 只显示标题。历史版本是「标题 + 细节」上下两行，细节缺失时用占位空格把
/// 第二行藏起来，导致卡片时而一行时而两行；现在统一成一行，视觉不再随阶段抖动。
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

                Text(activity.statusLineText)
                    .font(.appMicro)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 0)

                ProgressView()
                    .controlSize(.small)
                    .tint(theme.primary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                theme.primary.opacity(0.07),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(theme.primary.opacity(0.16), lineWidth: 0.5)
            )
            .frame(minHeight: 30)
        }
    }
}
