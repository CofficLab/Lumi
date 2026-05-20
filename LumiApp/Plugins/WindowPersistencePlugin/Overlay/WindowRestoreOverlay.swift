import AppKit
import MagicKit
import SwiftUI

/// 窗口状态恢复覆盖层
/// 在 App 启动时从磁盘恢复保存的窗口状态（会话、面板、编辑器、侧边栏）。
/// 窗口级项目路径的恢复由 `RecentProjectsPlugin` 负责。
struct WindowRestoreOverlay<Content: View>: View, SuperLog {
    nonisolated static var verbose: Bool { true }
    nonisolated static var emoji: String { "🪟" }

    let content: Content

    @EnvironmentObject private var windowManagerVM: WindowManagerVM

    var body: some View {
        content
            .onAppear {
                let coordinator = WindowPersistenceCoordinator.shared
                coordinator.attach(windowManagerVM: windowManagerVM)
                coordinator.restoreIfNeeded(
                    windowManagerVM: windowManagerVM,
                    openAdditionalWindow: { route in
                        NotificationCenter.default.post(
                            name: .openWindowWithRoute,
                            object: nil,
                            userInfo: ["route": route]
                        )
                    }
                )
            }
    }
}

// MARK: - Coordinator

@MainActor
private final class WindowPersistenceCoordinator {
    static let shared = WindowPersistenceCoordinator()

    private let maxRestoredWindowCount = 20
    private let store = WindowStateStore()

    private weak var windowManagerVM: WindowManagerVM?
    private var observers: [NSObjectProtocol] = []
    private var pendingRecords: [UUID: WindowPersistenceRecord] = [:]

    func attach(windowManagerVM: WindowManagerVM) {
        self.windowManagerVM = windowManagerVM
        guard observers.isEmpty else { return }

        let windowClosedObserver = NotificationCenter.default.addObserver(
            forName: .windowClosed,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.saveCurrentStates()
            }
        }

        let willTerminateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.saveCurrentStatesSynchronously()
            }
        }

        observers = [windowClosedObserver, willTerminateObserver]
    }

    func restoreIfNeeded(
        windowManagerVM: WindowManagerVM,
        openAdditionalWindow: (LumiWindowRoute) -> Void
    ) {
        applyPendingRecords(to: windowManagerVM.windowScopes)

        guard windowManagerVM.beginInitialStateRestorationIfNeeded() else { return }

        let records = Array(store.loadWindowStates().prefix(maxRestoredWindowCount))
        guard !records.isEmpty else {
            windowManagerVM.markInitialStateRestorationComplete()
            return
        }

        pendingRecords.removeAll()
        for record in records {
            pendingRecords[record.windowId] = record
        }

        if let firstScope = windowManagerVM.windowScopes.first,
           let firstRecord = records.first {
            apply(firstRecord, to: firstScope)
        } else {
            Task { @MainActor [weak self, weak windowManagerVM] in
                guard let windowManagerVM else { return }
                self?.applyPendingRecords(to: windowManagerVM.windowScopes)
            }
        }

        for record in records.dropFirst() {
            openAdditionalWindow(route(for: record))
        }

        windowManagerVM.markInitialStateRestorationComplete()
    }

    private func applyPendingRecords(to scopes: [WindowScope]) {
        for scope in scopes {
            guard let record = pendingRecords[scope.id] else { continue }
            apply(record, to: scope)
        }
    }

    private func apply(_ record: WindowPersistenceRecord, to scope: WindowScope) {
        scope.applyRoute(route(for: record))

        if let activePanel = record.activePanel.flatMap(WindowActivePanel.init(rawValue:)) {
            scope.activePanel = activePanel
        }

        if let editorState = record.editorState {
            scope.editorState = editorState
        }

        if let sidebarVisibility = record.sidebarVisibility {
            scope.sidebarVisibility = sidebarVisibility
        }

        pendingRecords.removeValue(forKey: scope.id)
    }

    private func route(for record: WindowPersistenceRecord) -> LumiWindowRoute {
        // projectPath 由 RecentProjectsPlugin 负责恢复，此处不再传递
        LumiWindowRoute(
            id: record.windowId,
            conversationId: record.conversationId
        )
    }

    private func saveCurrentStates() {
        guard let scopes = windowManagerVM?.windowScopes else { return }
        store.saveWindowStates(from: scopes)
    }

    private func saveCurrentStatesSynchronously() {
        guard let scopes = windowManagerVM?.windowScopes else { return }
        store.saveWindowStatesSynchronously(from: scopes)
    }
}

#Preview("Window Restore Overlay") {
    WindowRestoreOverlay(content: Text("Content"))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
}
