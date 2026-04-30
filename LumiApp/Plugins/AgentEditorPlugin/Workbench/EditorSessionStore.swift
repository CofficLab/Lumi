import Foundation
import Combine

@MainActor
final class EditorSessionStore: ObservableObject {
    @Published private(set) var sessions: [EditorSession] = []
    @Published private(set) var tabs: [EditorTab] = []
    @Published private(set) var activeSessionID: EditorSession.ID?

    private var navigationHistory = EditorNavigationHistory()
    private var bypassHistoryForSessionID: EditorSession.ID?

    var activeSession: EditorSession? {
        guard let activeSessionID else { return nil }
        return sessions.first(where: { $0.id == activeSessionID })
    }

    var canNavigateBack: Bool { navigationHistory.canGoBack }
    var canNavigateForward: Bool { navigationHistory.canGoForward }

    func recentActivationRank(for sessionID: EditorSession.ID) -> Int? {
        guard let index = navigationHistory.sessionIDs.lastIndex(of: sessionID) else { return nil }
        return navigationHistory.sessionIDs.distance(from: index, to: navigationHistory.sessionIDs.endIndex) - 1
    }

    @discardableResult
    func openOrActivate(fileURL: URL?) -> EditorSession? {
        guard let fileURL else {
            activeSessionID = nil
            return nil
        }

        if let existing = sessions.first(where: { $0.fileURL == fileURL }) {
            activeSessionID = existing.id
            recordActivation(for: existing.id)
            return existing
        }

        let session = EditorSession(fileURL: fileURL)
        sessions.append(session)
        tabs.append(EditorTab(sessionID: session.id, fileURL: fileURL))
        activeSessionID = session.id
        recordActivation(for: session.id)
        return session
    }

    func syncActiveSession(from snapshot: EditorSession) {
        guard let fileURL = snapshot.fileURL else {
            activeSessionID = nil
            return
        }

        let session = openOrActivate(fileURL: fileURL) ?? EditorSession(fileURL: fileURL)
        session.applySnapshot(from: snapshot)
        updateTab(for: session)
        activeSessionID = session.id
    }

    @discardableResult
    func activate(sessionID: EditorSession.ID) -> EditorSession? {
        guard let session = sessions.first(where: { $0.id == sessionID }) else { return nil }
        activeSessionID = session.id
        recordActivation(for: session.id)
        return session
    }

    func session(for sessionID: EditorSession.ID) -> EditorSession? {
        sessions.first(where: { $0.id == sessionID })
    }

    func togglePinned(sessionID: EditorSession.ID) {
        guard let index = tabs.firstIndex(where: { $0.sessionID == sessionID }) else { return }
        tabs[index].isPinned.toggle()
        normalizeTabOrder()
    }

    @discardableResult
    func reorderSession(
        sessionID: EditorSession.ID,
        before targetSessionID: EditorSession.ID?
    ) -> Bool {
        guard let fromIndex = tabs.firstIndex(where: { $0.sessionID == sessionID }) else { return false }

        let movingTab = tabs[fromIndex]
        tabs.remove(at: fromIndex)

        let insertionIndex: Int
        if let targetSessionID,
           let targetIndex = tabs.firstIndex(where: { $0.sessionID == targetSessionID }) {
            insertionIndex = targetIndex
        } else {
            insertionIndex = tabs.endIndex
        }

        tabs.insert(movingTab, at: max(0, min(insertionIndex, tabs.count)))
        normalizeTabOrder()
        return true
    }

    @discardableResult
    func close(sessionID: EditorSession.ID) -> EditorSession? {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else {
            return activeSession
        }

        let wasActive = activeSessionID == sessionID
        sessions.remove(at: index)
        tabs.removeAll(where: { $0.sessionID == sessionID })
        navigationHistory.remove(sessionID)

        guard !sessions.isEmpty else {
            activeSessionID = nil
            return nil
        }

        guard wasActive else {
            return activeSession
        }

        if let historySessionID = navigationHistory.currentSessionID,
           let historySession = session(for: historySessionID) {
            activeSessionID = historySession.id
            return historySession
        }

        let nextIndex = min(index, sessions.count - 1)
        let nextSession = sessions[nextIndex]
        activeSessionID = nextSession.id
        recordActivation(for: nextSession.id)
        return nextSession
    }

    @discardableResult
    func closeOthers(keeping sessionID: EditorSession.ID) -> EditorSession? {
        guard let kept = session(for: sessionID) else { return activeSession }
        sessions = [kept]
        tabs = tabs.filter { $0.sessionID == sessionID }
        activeSessionID = kept.id
        navigationHistory.clear()
        recordActivation(for: kept.id)
        return kept
    }

    @discardableResult
    func goBack() -> EditorSession? {
        guard let sessionID = navigationHistory.goBack() else { return nil }
        activeSessionID = sessionID
        bypassHistoryForSessionID = sessionID
        return session(for: sessionID)
    }

    @discardableResult
    func goForward() -> EditorSession? {
        guard let sessionID = navigationHistory.goForward() else { return nil }
        activeSessionID = sessionID
        bypassHistoryForSessionID = sessionID
        return session(for: sessionID)
    }

    func closeAll() {
        sessions.removeAll()
        tabs.removeAll()
        activeSessionID = nil
        navigationHistory.clear()
    }

    private func recordActivation(for sessionID: EditorSession.ID) {
        if bypassHistoryForSessionID == sessionID {
            bypassHistoryForSessionID = nil
            return
        }
        navigationHistory.recordVisit(sessionID)
    }

    private func updateTab(for session: EditorSession) {
        if let index = tabs.firstIndex(where: { $0.sessionID == session.id }) {
            tabs[index].fileURL = session.fileURL
            tabs[index].title = session.fileURL?.lastPathComponent ?? tabs[index].title
            tabs[index].isDirty = session.isDirty
        } else {
            tabs.append(
                EditorTab(
                    sessionID: session.id,
                    fileURL: session.fileURL,
                    isDirty: session.isDirty
                )
            )
        }
        normalizeTabOrder()
    }

    private func normalizeTabOrder() {
        let pinned = tabs.filter(\.isPinned)
        let unpinned = tabs.filter { !$0.isPinned }
        tabs = pinned + unpinned
        syncSessionsToTabOrder()
    }

    private func syncSessionsToTabOrder() {
        let sessionMap = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
        let orderedSessions = tabs.compactMap { sessionMap[$0.sessionID] }
        if orderedSessions.count == sessions.count {
            sessions = orderedSessions
        }
    }
}
