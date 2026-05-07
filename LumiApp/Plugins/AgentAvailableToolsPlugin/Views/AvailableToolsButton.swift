import SwiftUI

/// 状态栏上的可用工具按钮
struct AvailableToolsButton: View {
    @EnvironmentObject var conversationTurnServices: ConversationTurnServices

    var body: some View {
        StatusBarHoverContainer(
            detailView: AvailableToolsListDetailView(),
            popoverWidth: 480,
            id: "available-tools-status"
        ) {
            HStack(spacing: 4) {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.system(size: 10))
                Text(String(localized: "Tools", table: "AgentAvailableToolsPlugin"))
                    .font(.system(size: 11))
                    .lineLimit(1)
            }
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
