import SwiftUI

struct AutoApprovePersistenceOverlay<Content: View>: View {
    @EnvironmentObject private var projectVM: ProjectVM

    let content: Content
    private let store = AgentAutoApprovePersistenceStore()

    @State private var restored = false

    var body: some View {
        content
            .onAppear {
                handleOnAppear()
            }
            .onChange(of: projectVM.autoApproveRisk) { _, newValue in
                handleAutoApproveRiskChange(newValue)
            }
    }
}

// MARK: - View

// MARK: - Action

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

    private func handleAutoApproveRiskChange(_ newValue: Bool) {
        store.saveEnabled(newValue)
    }

    private func restoreIfNeeded() {
        guard !restored else { return }
        setRestored(true)
        guard let enabled = store.loadEnabled() else { return }
        projectVM.setAutoApproveRisk(enabled)
    }
}

// MARK: - Preview

#Preview("Auto Approve Persistence Overlay") {
    AutoApprovePersistenceOverlay {
        Text("Content")
    }
    .inRootView()
}