import LumiUI
import ProviderConversation
import SwiftUI

/// Chat Header 中显示当前会话标题的轻量视图。
///
/// 标题来源保持与旧版一致：由 ConversationManaging 统一提供，视图只负责
/// 订阅变更并展示，不复制会话标题的回退/持久化规则。
@MainActor
struct HeaderView: View {
    let conversations: any ConversationManaging

    @LumiTheme private var theme
    @State private var displayTitle = ""

    var body: some View {
        Text(displayTitle)
            .font(.appMicroEmphasized)
            .foregroundColor(theme.textPrimary)
            .lineLimit(1)
            .truncationMode(.middle)
            .task { refreshTitle() }
            .onReceive(conversations.objectWillChange) { _ in
                // objectWillChange from @Published is emitted before the value
                // assignment; refresh on the next main-actor turn to read the
                // new currentTitle rather than the old snapshot.
                Task { @MainActor in
                    await Task.yield()
                    refreshTitle()
                }
            }
    }

    private func refreshTitle() {
        displayTitle = conversations.currentTitle
    }
}
