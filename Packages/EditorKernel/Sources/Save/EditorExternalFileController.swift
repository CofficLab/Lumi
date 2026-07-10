import Foundation
import SuperLogKit
import os

@MainActor
public final class EditorExternalFileController: SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "editor.ext-file")
    nonisolated public static let emoji = "📄"
    nonisolated(unsafe) static var verbose: Bool = false

    public struct ConflictState: Equatable {
        public let content: String
        public let modificationDate: Date

        public init(content: String, modificationDate: Date) {
            self.content = content
            self.modificationDate = modificationDate
        }
    }

    private var pollTimer: Timer?
    private var lastKnownModificationDate: Date?
    public private(set) var conflictState: ConflictState?
    private let pollInterval: TimeInterval

    /// 心跳节流计数：每个文件 watcher 的轮询 tick 自增，每 N 次打一条日志。
    /// 每打开一个文件就会启动一个 \(pollInterval)Hz 主线程定时器，
    /// 多文件累积会成为主线程 runloop 负担，用于排查 100% CPU 时确认是否在持续轮询。
    private var tickCount = 0
    private let tickLogEvery = 10
    private var watchedURL: URL?

    public init(pollInterval: TimeInterval = 1.0) {
        self.pollInterval = pollInterval
    }

    public func setupWatcher(
        for url: URL,
        onPoll: @escaping @MainActor (_ url: URL, _ currentModDate: Date) -> Void
    ) {
        cleanupWatcher(clearConflict: {})

        watchedURL = url
        lastKnownModificationDate = Self.getModificationDate(of: url)
        if Self.verbose { Self.logger.info("\(self.t)启动文件轮询 \(url.lastPathComponent)，间隔 \(self.pollInterval)s（每打开一个文件即多一个主线程定时器）") }
        let timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            guard let currentModDate = Self.getModificationDate(of: url) else {
                return
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.tickCount += 1
                if Self.verbose, self.tickCount % self.tickLogEvery == 0 {
                    Self.logger.info("\(self.t)tick #\(self.tickCount) 轮询 \(url.lastPathComponent)")
                }
                onPoll(url, currentModDate)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    public func cleanupWatcher(clearConflict: @escaping @MainActor () -> Void) {
        if let url = watchedURL, pollTimer != nil, Self.verbose {
            Self.logger.info("\(self.t)停止文件轮询 \(url.lastPathComponent)")
        }
        pollTimer?.invalidate()
        pollTimer = nil
        watchedURL = nil
        lastKnownModificationDate = nil
        conflictState = nil
        clearConflict()
    }

    public func shouldReloadForChange(
        currentModDate: Date,
        hasUnsavedChanges: Bool
    ) -> Bool {
        if !hasUnsavedChanges,
           let lastDate = lastKnownModificationDate,
           currentModDate.timeIntervalSince(lastDate) < 0.5 {
            return false
        }
        return true
    }

    public func recordUnchangedModificationDate(_ date: Date) {
        lastKnownModificationDate = date
    }

    public func loadExternalText(from url: URL) async throws -> String? {
        try await Task.detached(priority: .userInitiated) {
            let fileHandle = try FileHandle(forReadingFrom: url)
            let data = try fileHandle.readToEnd()
            try fileHandle.close()
            guard let data else { return nil }
            return String(data: data, encoding: .utf8)
        }.value
    }

    public func registerConflictIfNeeded(content: String, modificationDate: Date) -> Bool {
        let candidate = ConflictState(content: content, modificationDate: modificationDate)
        if conflictState == candidate {
            return false
        }
        conflictState = candidate
        return true
    }

    public func clearConflict() {
        conflictState = nil
    }

    public func reloadConflict(
        applyExternalContent: @escaping @MainActor (_ content: String, _ modificationDate: Date) -> Void,
        clearConflict: @escaping @MainActor () -> Void,
        syncSession: @escaping @MainActor () -> Void
    ) {
        guard let conflictState else { return }
        applyExternalContent(conflictState.content, conflictState.modificationDate)
        clearConflict()
        syncSession()
    }

    public func keepEditorVersionForConflict(
        hasUnsavedChanges: Bool,
        clearConflict: @escaping @MainActor () -> Void,
        setSaveState: @escaping @MainActor (_ stateIsEditing: Bool) -> Void,
        syncSession: @escaping @MainActor () -> Void
    ) {
        guard let conflictState else { return }
        lastKnownModificationDate = conflictState.modificationDate
        clearConflict()
        setSaveState(hasUnsavedChanges)
        syncSession()
    }

    public func recordAppliedExternalContent(modificationDate: Date) {
        lastKnownModificationDate = modificationDate
        conflictState = nil
    }

    nonisolated public static func getModificationDate(of url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }
}
