import MagicAlert
import SwiftUI

/// 自动批准开关：控制是否自动批准高风险命令
struct AutoApproveToggle: View {
    @EnvironmentObject var projectVM: ProjectVM

    var body: some View {
        HStack(spacing: 6) {
            Text(String(localized: "Auto", table: "AgentAutoApproveHeader"))
                .font(DesignTokens.Typography.caption2)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)

            Toggle("", isOn: Binding(
                get: { projectVM.autoApproveRisk },
                set: { newValue in
                    projectVM.setAutoApproveRisk(newValue)
                    handleToggleChange(newValue)
                }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.05))
        .cornerRadius(6)
        .help(String(localized: "Auto-approve high-risk commands", table: "AgentAutoApproveHeader"))
    }
}

// MARK: - Action

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
