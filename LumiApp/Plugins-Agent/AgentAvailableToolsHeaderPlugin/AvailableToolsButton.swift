import SwiftUI

/// Chat header 上的可用工具按钮
struct AvailableToolsButton: View {
    @EnvironmentObject var conversationTurnServices: ConversationTurnServices

    @State private var isPresented = false

    private let iconSize: CGFloat = 14
    private let iconButtonSize: CGFloat = 28

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: iconSize))
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                .frame(width: iconButtonSize, height: iconButtonSize)
                .background(Color.black.opacity(0.05))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .help(String(localized: "Show tools", table: "AgentAvailableToolsHeader"))
        .sheet(isPresented: $isPresented) {
            AvailableToolsListSheetView(tools: conversationTurnServices.toolService.tools)
                .frame(minWidth: 720, minHeight: 520)
        }
    }
}

