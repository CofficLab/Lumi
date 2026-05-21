import AppKit
import SwiftUI

/// 监听窗口 VM 状态变化并防抖写入磁盘。
struct WindowPersistenceOverlay<Content: View>: View {
    let content: Content

    @EnvironmentObject private var windowManagerVM: WindowManagerVM
    @State private var persistTask: Task<Void, Never>?

    private let store = WindowStateStore()

    var body: some View {
        content
            .onChange(of: persistenceFingerprint) { _, _ in
                schedulePersist()
            }
            .onReceive(NotificationCenter.default.publisher(for: .windowStateShouldPersist)) { _ in
                schedulePersist()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                persistTask?.cancel()
                store.saveWindowStatesSynchronously(from: windowManagerVM.windowScopes)
            }
    }

    /// 聚合各窗口 scope / VM 的可持久化字段，用于触发保存。
    private var persistenceFingerprint: String {
        windowManagerVM.windowScopes.map { scope in
            [
                scope.id.uuidString,
                scope.projectPath ?? "",
                scope.selectedConversationId?.uuidString ?? "",
                scope.activePanel.rawValue,
                String(scope.sidebarVisibility),
                scope.editorState.openFileURLs.map(\.path).joined(separator: ","),
                scope.editorState.activeFileURL?.path ?? "",
            ].joined(separator: "|")
        }.joined(separator: ";")
    }

    private func schedulePersist() {
        persistTask?.cancel()
        persistTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            store.saveWindowStates(from: windowManagerVM.windowScopes)
        }
    }
}

#Preview("Window Persistence Overlay") {
    WindowPersistenceOverlay(content: Text("Content"))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .inRootView()
}
