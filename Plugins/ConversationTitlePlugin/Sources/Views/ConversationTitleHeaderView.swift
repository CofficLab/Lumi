import LumiKernel
import LumiUI
import SwiftUI

/// Header view displaying the current conversation title
struct ConversationTitleHeaderView: View {
    let kernel: LumiKernel
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    // 只订阅 conversations 这一个 service：本视图不挂在 kernel 全局总线上，
    // project/workspace/settings 等无关服务变更不会触发这里刷新。
    @StateObject private var box = ObservableConversationsBox()

    var body: some View {
        Text(displayTitle)
            .font(.appMicroEmphasized)
            .foregroundColor(theme.textPrimary)
            .lineLimit(1)
            .task { box.bind(kernel.conversations) }
    }

    private var displayTitle: String {
        box.service?.currentTitle ?? ""
    }
}
