import MagicAlert
import SwiftUI

/// 自动批准开关：控制是否自动批准高风险命令
struct AutoApproveToggle: View {
    @EnvironmentObject var projectVM: ProjectVM
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        let theme = themeManager.activeAppTheme

        Toggle("Auto", isOn: Binding(
            get: { projectVM.autoApproveRisk },
            set: { newValue in
                projectVM.setAutoApproveRisk(newValue)
                handleToggleChange(newValue)
            }
        ))
        .toggleStyle(.switch)
        .controlSize(.mini)
        .foregroundColor(theme.workspaceTextColor())
        .help(String(localized: "Auto-approve high-risk commands", table: "AgentAutoApproveHeader"))
    }
}

// MARK: - View

// MARK: - Action

// MARK: - Setter

// MARK: - Event Handler

extension AutoApproveToggle {
    func handleToggleChange(_ enabled: Bool) {
        let message = enabled
            ? String(localized: "Auto-approve high-risk commands enabled", table: "AgentAutoApproveHeader")
            : String(localized: "Auto-approve high-risk commands disabled", table: "AgentAutoApproveHeader")
        alert_info(message)
    }
}

// MARK: - Preview

#Preview("Auto Approve Toggle") {
    AutoApproveToggle()
        .padding()
        .background(Color.black)
        .inRootView()
}
