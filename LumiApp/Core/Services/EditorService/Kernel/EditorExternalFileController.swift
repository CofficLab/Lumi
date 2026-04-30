import Foundation

@MainActor
final class EditorExternalFileController {
    struct ConflictState: Equatable {
        let content: String
        let modificationDate: Date
    }

    private var pollTimer: Timer?
    private var lastKnownModificationDate: Date?
    private(set) var conflictState: ConflictState?
    private let pollInterval: TimeInterval

    init(pollInterval: TimeInterval = 1.0) {
        self.pollInterval = pollInterval
    }

    func setupWatcher(
        for url: URL,
        onPoll: @escaping @MainActor (_ url: URL, _ currentModDate: Date) -> Void
    ) {
        cleanupWatcher(clearConflict: {})

        lastKnownModificationDate = Self.getModificationDate(of: url)
        let timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { _ in
            guard let currentModDate = Self.getModificationDate(of: url) else {
                return
            }
            DispatchQueue.main.async {
                onPoll(url, currentModDate)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    func cleanupWatcher(clearConflict: @escaping @MainActor () -> Void) {
        pollTimer?.invalidate()
        pollTimer = nil
        lastKnownModificationDate = nil
        conflictState = nil
        clearConflict()
    }

    func shouldReloadForChange(
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

    func recordUnchangedModificationDate(_ date: Date) {
        lastKnownModificationDate = date
    }

    func loadExternalText(from url: URL) async throws -> String? {
        try await Task.detached(priority: .userInitiated) {
            let fileHandle = try FileHandle(forReadingFrom: url)
            let data = try fileHandle.readToEnd()
            try fileHandle.close()
            guard let data else { return nil }
            return String(data: data, encoding: .utf8)
        }.value
    }

    func registerConflictIfNeeded(content: String, modificationDate: Date) -> Bool {
        let candidate = ConflictState(content: content, modificationDate: modificationDate)
        if conflictState == candidate {
            return false
        }
        conflictState = candidate
        return true
    }

    func clearConflict() {
        conflictState = nil
    }

    func reloadConflict(
        applyExternalContent: @escaping @MainActor (_ content: String, _ modificationDate: Date) -> Void,
        clearConflict: @escaping @MainActor () -> Void,
        syncSession: @escaping @MainActor () -> Void
    ) {
        guard let conflictState else { return }
        applyExternalContent(conflictState.content, conflictState.modificationDate)
        clearConflict()
        syncSession()
    }

    func keepEditorVersionForConflict(
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

    func recordAppliedExternalContent(modificationDate: Date) {
        lastKnownModificationDate = modificationDate
        conflictState = nil
    }

    static func getModificationDate(of url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }
}
