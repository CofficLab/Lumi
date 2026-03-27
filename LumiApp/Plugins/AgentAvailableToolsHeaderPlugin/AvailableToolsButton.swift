import SwiftUI

/// Chat header 上的可用工具按钮
struct AvailableToolsButton: View {
    @EnvironmentObject var conversationTurnServices: ConversationTurnServices

    @State private var isPresented = false

    private let iconSize: CGFloat = 14
    private let iconButtonSize: CGFloat = 28

    var body: some View {
        Button {
            handleButtonTap()
        } label: {
            buttonIcon
        }
        .buttonStyle(.plain)
        .help(String(localized: "Show tools", table: "AgentAvailableToolsHeader"))
        .sheet(isPresented: $isPresented) {
            toolListSheet
        }
    }
}

// MARK: - View

extension AvailableToolsButton {
    private var buttonIcon: some View {
        Image(systemName: "wrench.and.screwdriver")
            .font(.system(size: iconSize))
            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            .frame(width: iconButtonSize, height: iconButtonSize)
            .background(Color.black.opacity(0.05))
            .clipShape(Circle())
    }

    private var toolListSheet: some View {
        AvailableToolsListSheetView(tools: conversationTurnServices.toolService.tools)
            .frame(minWidth: 720, minHeight: 520)
    }
}

// MARK: - Action

extension AvailableToolsButton {
    func handleButtonTap() {
        isPresented = true
    }
}

// MARK: - Preview

#Preview {
    AvailableToolsButton()
        .inRootView()
}