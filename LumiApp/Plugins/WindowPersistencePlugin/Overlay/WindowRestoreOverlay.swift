import AppKit
import MagicKit
import os
import SwiftUI

/// 窗口状态恢复覆盖层
/// 在 App 启动时从磁盘恢复保存的窗口状态（项目、会话、面板、编辑器、侧边栏）。
struct WindowRestoreOverlay<Content: View>: View, SuperLog {
    nonisolated static var verbose: Bool { true }
    nonisolated static var emoji: String { "🪟" }

    let content: Content

    @EnvironmentObject private var windowManagerVM: WindowManagerVM

    var body: some View {
        content
            .onAppear {
                WindowPersistenceCoordinator.shared.ensureAttached(
                    windowManagerVM: windowManagerVM
                )
            }
    }
}

// MARK: - Coordinator

@MainActor
final class WindowPersistenceCoordinator {
    static let shared = WindowPersistenceCoordinator()

    private static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.window-persistence"
    )

    private let maxRestoredWindowCount = 20
    private let store = WindowStateStore()

    private weak var windowManagerVM: WindowManagerVM?
    private var observers: [NSObjectProtocol] = []
    private var pendingRecords: [UUID: WindowPersistenceRecord] = [:]
    private var pendingRecordsInOrder: [WindowPersistenceRecord] = []
    private(set) var isAwaitingFirstScopeForRestore = false
    private var hasPreparedInitialRestoration = false

    /// 启动时窗口状态恢复是否已全部结束（含将磁盘项目写入首个 scope）
    var isInitialRestorationFinished: Bool {
        guard hasPreparedInitialRestoration else { return false }
        guard !isAwaitingFirstScopeForRestore else { return false }
        return windowManagerVM?.hasCompletedInitialStateRestoration ?? false
    }
    private var openAdditionalWindowHandler: ((LumiWindowRoute) -> Void)?

    private init() {
        installApplicationLaunchObserver()
    }

    /// 插件注册时预热，确保能收到 `applicationDidFinishLaunching`
    static func warmUp() {
        _ = shared
    }

    private func installApplicationLaunchObserver() {
        NotificationCenter.default.addObserver(
            forName: .applicationDidFinishLaunching,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let windowManagerVM = RootContainer.shared.windowManagerVM
                self.ensureAttached(windowManagerVM: windowManagerVM)
                self.prepareInitialRestoration(windowManagerVM: windowManagerVM)
            }
        }
    }

    func ensureAttached(windowManagerVM: WindowManagerVM) {
        attach(windowManagerVM: windowManagerVM)
    }

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

        let scopeRegisteredObserver = NotificationCenter.default.addObserver(
            forName: .windowScopeDidRegister,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let scope = notification.object as? WindowScope else { return }
            MainActor.assumeIsolated {
                self?.onScopeRegistered(scope)
            }
        }

        let persistObserver = NotificationCenter.default.addObserver(
            forName: .windowStateShouldPersist,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.saveCurrentStatesImmediately()
            }
        }

        observers = [windowClosedObserver, willTerminateObserver, scopeRegisteredObserver, persistObserver]
    }

    /// 应用启动后、首个窗口注册前：加载磁盘记录并等待 scope
    private func prepareInitialRestoration(windowManagerVM: WindowManagerVM) {
        guard !hasPreparedInitialRestoration else { return }
        hasPreparedInitialRestoration = true

        openAdditionalWindowHandler = { route in
            NotificationCenter.default.post(
                name: .openWindowWithRoute,
                object: nil,
                userInfo: ["route": route]
            )
        }

        applyPendingRecords(to: windowManagerVM.windowScopes)

        guard windowManagerVM.beginInitialStateRestorationIfNeeded() else { return }

        let records = Array(store.loadWindowStates().prefix(maxRestoredWindowCount))
        Self.logger.info(
            "🪟 prepare restoration: loaded \(records.count, privacy: .public) record(s)"
        )

        guard !records.isEmpty else {
            windowManagerVM.markInitialStateRestorationComplete()
            return
        }

        if let path = records.first?.projectPath {
            Self.logger.info("🪟 first record projectPath: \(path, privacy: .public)")
        } else {
            Self.logger.warning("🪟 first record has no projectPath")
        }

        pendingRecords = Dictionary(uniqueKeysWithValues: records.map { ($0.windowId, $0) })
        pendingRecordsInOrder = records
        isAwaitingFirstScopeForRestore = true

        if let firstScope = windowManagerVM.windowScopes.first {
            applyFirstRecordIfNeeded(to: firstScope, windowManagerVM: windowManagerVM)
        }
    }

    private func onScopeRegistered(_ scope: WindowScope) {
        guard isAwaitingFirstScopeForRestore,
              let windowManagerVM else { return }
        Self.logger.info(
            "🪟 onScopeRegistered scope=\(scope.id.uuidString.prefix(8), privacy: .public) awaiting restore"
        )
        applyFirstRecordIfNeeded(to: scope, windowManagerVM: windowManagerVM)
    }

    /// 将第一条保存记录应用到首个注册的窗口（重启后 windowId 通常与磁盘不一致，按顺序对齐）。
    private func applyFirstRecordIfNeeded(to scope: WindowScope, windowManagerVM: WindowManagerVM) {
        guard isAwaitingFirstScopeForRestore,
              let firstRecord = pendingRecordsInOrder.first else { return }

        apply(firstRecord, to: scope)
        isAwaitingFirstScopeForRestore = false

        Self.logger.info(
            "🪟 applied first record to scope=\(scope.id.uuidString.prefix(8), privacy: .public) projectSelected=\(scope.projectVM.isProjectSelected, privacy: .public)"
        )

        for record in pendingRecordsInOrder.dropFirst() {
            openAdditionalWindowHandler?(route(for: record))
            pendingRecords.removeValue(forKey: record.windowId)
        }

        pendingRecordsInOrder.removeAll()
        openAdditionalWindowHandler = nil
        windowManagerVM.markInitialStateRestorationComplete()
    }

    private func applyPendingRecords(to scopes: [WindowScope]) {
        for scope in scopes {
            guard let record = pendingRecords[scope.id] else { continue }
            apply(record, to: scope)
        }
    }

    private func apply(_ record: WindowPersistenceRecord, to scope: WindowScope) {
        scope.conversationVM.setSelectedConversation(record.conversationId)

        if let projectPath = record.projectPath, !projectPath.isEmpty {
            let projectName = URL(fileURLWithPath: projectPath).lastPathComponent
            scope.projectVM.switchProject(
                to: Project(name: projectName, path: projectPath, lastUsed: Date())
            )
        }

        if let activePanel = record.activePanel.flatMap(WindowActivePanel.init(rawValue:)) {
            scope.activePanel = activePanel
        } else if record.conversationId != nil {
            scope.activePanel = .chat
        } else if record.projectPath != nil {
            scope.activePanel = .fileTree
        }

        if let editorState = record.editorState {
            scope.editorState = editorState
        }

        if let sidebarVisibility = record.sidebarVisibility {
            scope.sidebarVisibility = sidebarVisibility
        }

        scope.updateTitle()
        pendingRecords.removeValue(forKey: record.windowId)
    }

    private func route(for record: WindowPersistenceRecord) -> LumiWindowRoute {
        LumiWindowRoute(
            id: record.windowId,
            conversationId: record.conversationId,
            projectPath: record.projectPath
        )
    }

    // MARK: - Automation / Debug

    func debugSnapshot() -> [String: Any] {
        let scopes = windowManagerVM?.windowScopes ?? []
        let records = store.loadWindowStates()
        return [
            "scopeCount": scopes.count,
            "scopes": scopes.map { scope in
                [
                    "id": scope.id.uuidString,
                    "projectPath": scope.projectPath ?? "",
                    "isProjectSelected": scope.projectVM.isProjectSelected,
                ] as [String: Any]
            },
            "diskRecordCount": records.count,
            "diskFirstProjectPath": records.first?.projectPath ?? "",
            "hasCompletedRestoration": windowManagerVM?.hasCompletedInitialStateRestoration ?? false,
            "isAwaitingFirstScope": isAwaitingFirstScopeForRestore,
        ]
    }

    private func saveCurrentStates() {
        guard let scopes = windowManagerVM?.windowScopes, !scopes.isEmpty else { return }
        store.saveWindowStates(from: scopes)
    }

    private func saveCurrentStatesSynchronously() {
        guard let scopes = windowManagerVM?.windowScopes, !scopes.isEmpty else { return }
        store.saveWindowStatesSynchronously(from: scopes)
    }

    private func saveCurrentStatesImmediately() {
        guard let scopes = windowManagerVM?.windowScopes, !scopes.isEmpty else { return }
        store.saveWindowStatesSynchronously(from: scopes)
    }
}

#Preview("Window Restore Overlay") {
    WindowRestoreOverlay(content: Text("Content"))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
}
