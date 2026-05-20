import MagicKit
import SwiftUI

/// 窗口状态恢复覆盖层
/// 在 App 启动时从磁盘恢复保存的窗口状态。
struct WindowRestoreOverlay<Content: View>: View, SuperLog {
    nonisolated static var verbose: Bool { true }
    nonisolated static var emoji: String { "🪟" }

    let content: Content

    @EnvironmentObject private var windowManagerVM: WindowManagerVM
    @State private var restored = false

    private let store = WindowStateStore()

    var body: some View {
        content
            .onAppear {
                handleOnAppear()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notification in
                handleWindowWillClose(notification)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                handleAppWillTerminate()
            }
    }
}

// MARK: - Event Handler

extension WindowRestoreOverlay {
    @MainActor
    private func handleOnAppear() {
        guard !restored else { return }

        let snapshots = store.loadWindowStates()
        guard !snapshots.isEmpty else {
            windowManagerVM.markInitialStateRestorationComplete()
            restored = true
            return
        }

        let routes = snapshots.map { snapshot in
            LumiWindowRoute(
                id: snapshot.windowId,
                conversationId: snapshot.conversationId,
                projectPath: snapshot.projectPath
            )
        }

        windowManagerVM.restoreSavedWindowStates(
            routes: routes,
            openAdditionalWindow: { route in
                NotificationCenter.default.post(
                    name: .openWindowWithRoute,
                    object: nil,
                    userInfo: ["route": route]
                )
            }
        )

        restored = true
    }

    private func handleWindowWillClose(_ notification: Notification) {
        Task { @MainActor in
            saveCurrentStates()
        }
    }

    private func handleAppWillTerminate() {
        Task { @MainActor in
            saveCurrentStates()
        }
    }

    @MainActor
    private func saveCurrentStates() {
        let scopes = windowManagerVM.windowScopes
        store.saveWindowStates(from: scopes)
    }
}

#Preview("Window Restore Overlay") {
    WindowRestoreOverlay(content: Text("Content"))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
}
