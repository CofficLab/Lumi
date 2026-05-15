import SwiftUI

struct IdleTimeRootObserver<Content: View>: View {
    @EnvironmentObject private var projectVM: ProjectVM
    let content: Content

    var body: some View {
        content
            .onAppear {
                recordProjectIfNeeded(projectVM.currentProjectPath)
            }
            .onChange(of: projectVM.currentProjectPath) { _, newValue in
                recordProjectIfNeeded(newValue)
            }
            .onApplicationDidBecomeActive {
                Task {
                    await IdleTimeService.shared.record(.appBecameActive)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .lumiEditorSave)) { _ in
                Task {
                    await IdleTimeService.shared.record(.fileSave)
                }
            }
    }

    private func recordProjectIfNeeded(_ path: String) {
        guard !path.isEmpty else { return }
        Task {
            await IdleTimeService.shared.record(.projectChanged)
        }
    }
}
