import LumiUI
import SwiftUI

/// Chat Header 中显示当前会话标题的轻量视图。
///
/// 标题来源保持与旧版一致：由 ConversationManaging 统一提供，视图只负责
/// 订阅变更并展示，不复制会话标题的回退/持久化规则。
@MainActor
struct HeaderView: View {
    @ObservedObject var state: ConversationTitleHeaderState

    @LumiTheme private var theme

    var body: some View {
        Text(state.title)
            .font(.appMicroEmphasized)
            .foregroundColor(theme.textPrimary)
            .lineLimit(1)
            .truncationMode(.middle)
    }
}
