import MagicAlert
import SwiftUI

/// 自动批准开关：控制是否自动批准高风险命令
struct AutoApproveToggle: View {
    @EnvironmentObject var projectVM: ProjectVM
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        let theme = themeManager.activeAppTheme

        Toggle(String(localized: "Auto", table: "AgentAutoApprovePlugin"), isOn: Binding(
            get: { projectVM.autoApproveRisk },
            set: { newValue in
                projectVM.setAutoApproveRisk(newValue)
                handleToggleChange(newValue)
            }
        ))
        .toggleStyle(.switch)
        .controlSize(.mini)
        .foregroundColor(theme.workspaceTextColor())
        .help(String(localized: "Auto-approve high-risk commands", table: "AgentAutoApprovePlugin"))
    }
}

// MARK: - Event Handler

extension AutoApproveToggle {
    func handleToggleChange(_ enabled: Bool) {
        let message = enabled
            ? String(localized: "Auto-approve high-risk commands enabled", table: "AgentAutoApprovePlugin")
            : String(localized: "Auto-approve high-risk commands disabled", table: "AgentAutoApprovePlugin")
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
