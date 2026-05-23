import SwiftUI
import LumiUI

/// 状态栏上的可用工具按钮
struct AvailableToolsButton: View {
    @EnvironmentObject var conversationTurnServices: AppConversationTurnVM

    var body: some View {
        StatusBarHoverContainer(
            detailView: AvailableToolsListDetailView(),
            popoverWidth: 680,
            id: "available-tools-status"
        ) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.appMicroEmphasized)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
        }
    }
}

// MARK: - Preview

#Preview {
    AvailableToolsButton()
        .inRootView()
}
