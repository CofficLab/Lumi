import SwiftUI

/// Chat header 上的可用工具按钮
struct AvailableToolsButton: View {
    @EnvironmentObject var conversationTurnServices: ConversationTurnServices
    @EnvironmentObject private var themeManager: ThemeManager

    @State private var isPresented = false

    private let iconSize: CGFloat = 14
    private let iconButtonSize: CGFloat = 28

    var body: some View {
        let theme = themeManager.activeAppTheme

        Button {
            handleButtonTap()
        } label: {
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: iconSize))
                .foregroundColor(theme.workspaceSecondaryTextColor())
                .frame(width: iconButtonSize, height: iconButtonSize)
                .background(theme.workspaceTextColor().opacity(0.06))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .help(String(localized: "Show tools", table: "AgentAvailableToolsPlugin"))
        .sheet(isPresented: $isPresented) {
            toolListSheet
        }
    }
}

// MARK: - View

extension AvailableToolsButton {

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
