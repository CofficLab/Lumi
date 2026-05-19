import SwiftUI

/// 状态栏上的可用工具按钮
struct AvailableToolsButton: View {
    @EnvironmentObject var conversationTurnServices: AppConversationTurnServicesVM

    var body: some View {
        StatusBarHoverContainer(
            detailView: AvailableToolsListDetailView(),
            popoverWidth: 680,
            id: "available-tools-status"
        ) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 10))
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
