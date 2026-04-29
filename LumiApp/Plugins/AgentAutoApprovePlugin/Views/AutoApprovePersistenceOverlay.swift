import SwiftUI

/// 自动批准持久化覆盖层
///
/// 包裹在根视图之上，监听项目切换和开关状态变化，自动保存/恢复设置。
struct AutoApprovePersistenceOverlay<Content: View>: View {
    @EnvironmentObject private var projectVM: ProjectVM

    let content: Content
    private let store = AgentAutoApprovePluginLocalStore.shared

    @State private var restored = false

    var body: some View {
        content
            .onAppear {
                handleOnAppear()
            }
            .onChange(of: projectVM.currentProjectPath) { _, newPath in
                handleProjectPathChange(newPath)
            }
            .onChange(of: projectVM.autoApproveRisk) { _, newValue in
                handleAutoApproveRiskChange(newValue)
            }
    }
}

// MARK: - Setter

extension AutoApprovePersistenceOverlay {
    @MainActor
    private func setRestored(_ value: Bool) {
        restored = value
    }
}

// MARK: - Event Handler

extension AutoApprovePersistenceOverlay {
    private func handleOnAppear() {
        restoreIfNeeded()
    }

    private func handleProjectPathChange(_ newPath: String) {
        setRestored(false)
        restoreIfNeeded()
    }

    private func handleAutoApproveRiskChange(_ newValue: Bool) {
        let projectPath = projectVM.currentProjectPath
        guard !projectPath.isEmpty else { return }
        store.saveEnabled(newValue, for: projectPath)
    }

    private func restoreIfNeeded() {
        let projectPath = projectVM.currentProjectPath
        guard !projectPath.isEmpty else { return }
        guard !restored else { return }
        setRestored(true)
        guard let enabled = store.loadEnabled(for: projectPath) else { return }
        projectVM.setAutoApproveRisk(enabled)
    }
}
