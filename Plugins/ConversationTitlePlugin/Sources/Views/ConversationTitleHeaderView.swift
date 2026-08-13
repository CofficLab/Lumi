import KernelLumi
import LumiUI
import SwiftUI

/// Header view displaying the current conversation title
struct ConversationTitleHeaderView: View {
    let kernel: KernelLumi
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    // 标题随当前选中会话变化。用事件 + @State 缓存，不挂 kernel 全局总线。
    @State private var displayTitle: String = ""

    var body: some View {
        Text(displayTitle)
            .font(.appMicroEmphasized)
            .foregroundColor(theme.textPrimary)
            .lineLimit(1)
            .task { refreshTitle() }
            .onLumiSelectedConversationDidChange { refreshTitle() }
            .onLumiConversationTitleDidChange { _ in refreshTitle() }
    }

    private func refreshTitle() {
        displayTitle = kernel.conversations?.currentTitle ?? ""
    }
}
