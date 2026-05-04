import MagicAlert
import SwiftUI

/// 自动批准开关：控制是否自动批准高风险命令
struct AutoApproveToggle: View {
    @EnvironmentObject var projectVM: ProjectVM
    @EnvironmentObject private var themeVM: ThemeVM

    private let store = AgentAutoApprovePluginLocalStore.shared

    var body: some View {
        let theme = themeVM.activeAppTheme

        Toggle(String(localized: "Auto", table: "AgentAutoApprovePlugin"), isOn: Binding(
            get: { projectVM.autoApproveRisk },
            set: { newValue in
                projectVM.setAutoApproveRisk(newValue)
                saveToStore(newValue)
                handleToggleChange(newValue)
            }
        ))
        .toggleStyle(.switch)
        .controlSize(.mini)
        .foregroundColor(theme.workspaceTextColor())
        .help(String(localized: "Auto-approve high-risk commands", table: "AgentAutoApprovePlugin"))
        .onAppear(perform: restoreFromStore)
        .onChange(of: projectVM.currentProjectPath) { _, _ in
            restoreFromStore()
        }
    }

    private func restoreFromStore() {
        let path = projectVM.currentProjectPath
        guard !path.isEmpty else { return }
        if let saved = store.loadEnabled(for: path) {
            projectVM.setAutoApproveRisk(saved)
        }
    }

    private func saveToStore(_ enabled: Bool) {
        let path = projectVM.currentProjectPath
        guard !path.isEmpty else { return }
        store.saveEnabled(enabled, for: path)
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
