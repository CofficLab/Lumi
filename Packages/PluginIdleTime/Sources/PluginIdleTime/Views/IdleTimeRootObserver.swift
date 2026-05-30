import AppKit
import SwiftUI
import LumiCoreKit

extension Notification.Name {
    static let lumiEditorSave = Notification.Name("LumiEditorSave")
}

public struct IdleTimeRootObserver<Content: View>: View {
    @EnvironmentObject private var projectVM: WindowProjectVM
    public let content: Content

    public var body: some View {
        content
            .onAppear {
                recordProjectIfNeeded(projectVM.currentProjectPath)
            }
            .onChange(of: projectVM.currentProjectPath) { _, newValue in
                recordProjectIfNeeded(newValue)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
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
