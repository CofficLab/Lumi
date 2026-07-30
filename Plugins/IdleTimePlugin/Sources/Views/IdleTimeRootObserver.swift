import AppKit
import SwiftUI
import LumiKernel

extension Notification.Name {
    static let lumiEditorSave = Notification.Name("LumiEditorSave")
}

public struct IdleTimeRootObserver<Content: View>: View {
    let provider: (any IdleTimeProviding)?
    let projectPathProvider: () -> String
    public let content: Content

    public init(
        provider: (any IdleTimeProviding)? = nil,
        projectPathProvider: @escaping () -> String = { "" },
        content: Content
    ) {
        self.provider = provider
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
                    await provider?.record(.appBecameActive)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .lumiEditorSave)) { _ in
                Task {
                    await provider?.record(.fileSave)
                }
            }
    }

    private func recordProjectIfNeeded(_ path: String) {
        guard !path.isEmpty else { return }
        Task {
            await provider?.record(.projectChanged)
        }
    }
}
