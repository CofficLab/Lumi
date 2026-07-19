import AppKit
import SwiftUI
import LumiKernel

extension Notification.Name {
    static let lumiEditorSave = Notification.Name("LumiEditorSave")
}

public struct IdleTimeRootObserver<Content: View>: View {
    let projectPathProvider: () -> String
    public let content: Content

    public init(
        projectPathProvider: @escaping () -> String = { "" },
        content: Content
    ) {
        self.projectPathProvider = projectPathProvider
        self.content = content
    }

    public var body: some View {
        content
            .onAppear {
                recordProjectIfNeeded(projectPathProvider())
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
