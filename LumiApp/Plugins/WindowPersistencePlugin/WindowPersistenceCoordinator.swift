import AppKit
import Foundation
import os

/// 窗口状态保存与启动恢复（单例，全局防抖写盘 + 一次性多窗口恢复）。
@MainActor
final class WindowPersistenceCoordinator: SuperLog {
    nonisolated static var emoji: String { WindowPersistencePlugin.emoji }
    nonisolated static var verbose: Bool { WindowPersistencePlugin.verbose }
    nonisolated static var logger: Logger { WindowPersistencePlugin.logger }

    static let shared = WindowPersistenceCoordinator()

    private let store = WindowStateStore()
    private weak var windowManagerVM: WindowManagerVM?
    private var observers: [NSObjectProtocol] = []
    private var pendingRecords: [UUID: WindowPersistenceRecord] = [:]
    private var persistTask: Task<Void, Never>?

    private init() {}

    // MARK: - Attach

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
                self?.persistTask?.cancel()
                self?.saveCurrentStatesSynchronously()
            }
        }

        observers = [windowClosedObserver, willTerminateObserver]
    }

    // MARK: - Save

    func scheduleSave() {
        persistTask?.cancel()
        persistTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            saveCurrentStates()
        }
    }

    func saveCurrentStates() {
        guard let containers = windowManagerVM?.windowContainers else { return }
        store.saveWindowStates(from: containers)
        if Self.verbose {
            Self.logger.info("\(Self.t) saved \(containers.count, privacy: .public) window state(s)")
        }
    }

    func saveCurrentStatesSynchronously() {
        guard let containers = windowManagerVM?.windowContainers else { return }
        store.saveWindowStatesSynchronously(from: containers)
    }

    // MARK: - Restore

    func restoreIfNeeded(
        windowManagerVM: WindowManagerVM,
        openAdditionalWindow: @escaping (LumiWindowRoute) -> Void
    ) {
        attach(windowManagerVM: windowManagerVM)
        applyPendingRecords(to: windowManagerVM.windowContainers)

        guard windowManagerVM.beginInitialStateRestorationIfNeeded() else { return }

        let records = Array(store.loadWindowStates().prefix(WindowStateStore.maxPersistedWindowCount))
        if Self.verbose {
            Self.logger.info("\(Self.t) prepare restoration: \(records.count, privacy: .public) record(s)")
        }

        guard !records.isEmpty else {
            windowManagerVM.markInitialStateRestorationComplete()
            return
        }

        pendingRecords = Dictionary(uniqueKeysWithValues: records.map { ($0.windowId, $0) })

        if let firstContainer = windowManagerVM.windowContainers.first,
           let firstRecord = records.first {
            apply(firstRecord, to: firstContainer)
            if Self.verbose {
                Self.logger.info(
                    "\(Self.t) applied first record projectPath=\(firstRecord.projectPath ?? "nil", privacy: .public)"
                )
            }
        }

        for record in records.dropFirst() {
            openAdditionalWindow(route(for: record))
        }

        if !pendingRecords.isEmpty {
            Task { @MainActor [weak self, weak windowManagerVM] in
                for delayMs in [500, 1000, 1500] {
                    try? await Task.sleep(for: .milliseconds(delayMs))
                    guard let windowManagerVM, let self else { return }
                    self.applyPendingRecords(to: windowManagerVM.windowContainers)
                    if self.pendingRecords.isEmpty { break }
                }
            }
        }

        windowManagerVM.markInitialStateRestorationComplete()
    }

    private func applyPendingRecords(to containers: [WindowContainer]) {
        for container in containers {
            applyPendingRecordIfNeeded(to: container)
        }
    }

    private func applyPendingRecordIfNeeded(to container: WindowContainer) {
        guard let record = pendingRecords[container.id] else { return }
        apply(record, to: container)
    }

    private func apply(_ record: WindowPersistenceRecord, to container: WindowContainer) {
        container.applyPersistenceRecord(record)
        pendingRecords.removeValue(forKey: container.id)
    }

    private func route(for record: WindowPersistenceRecord) -> LumiWindowRoute {
        LumiWindowRoute(id: record.windowId, projectPath: record.projectPath)
    }
}
