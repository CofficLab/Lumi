import Foundation
import Combine
import os

@MainActor
public final class EditorSessionStore: ObservableObject {
    @Published public private(set) var sessions: [EditorSession] = []
    @Published public private(set) var tabs: [EditorTab] = []
    @Published public private(set) var activeSessionID: EditorSession.ID?

    private var navigationHistory = EditorNavigationHistory()
    private var bypassHistoryForSessionID: EditorSession.ID?

    private static let logger = Logger(subsystem: EditorHostEnvironment.current.logSubsystem, category: "editor.session-store")

    public var activeSession: EditorSession? {
        guard let activeSessionID else { return nil }
        return sessions.first(where: { $0.id == activeSessionID })
    }

    public var canNavigateBack: Bool { navigationHistory.canGoBack }
    public var canNavigateForward: Bool { navigationHistory.canGoForward }

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
            recordActivation(for: existing)
            return existing
        }

        let session = EditorSession(fileURL: fileURL)
        sessions.append(session)
        tabs.append(EditorTab(sessionID: session.id, fileURL: fileURL))
        activeSessionID = session.id
        recordActivation(for: session)
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
        if navigationHistory.currentSessionID == session.id {
            navigationHistory.replaceCurrent(with: session)
        }
    }

    @discardableResult
    func activate(sessionID: EditorSession.ID) -> EditorSession? {
        guard let session = sessions.first(where: { $0.id == sessionID }) else { return nil }
        activeSessionID = session.id
        recordActivation(for: session)
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
        recordActivation(for: nextSession)
        return nextSession
    }

    @discardableResult
    func closeOthers(keeping sessionID: EditorSession.ID) -> EditorSession? {
        guard let kept = session(for: sessionID) else { return activeSession }
        sessions = [kept]
        tabs = tabs.filter { $0.sessionID == sessionID }
        activeSessionID = kept.id
        navigationHistory.clear()
        recordActivation(for: kept)
        return kept
    }

    @discardableResult
    func closeTabsToLeft(of sessionID: EditorSession.ID) -> EditorSession? {
        closeTabs(relativeTo: sessionID) { tabIndex, referenceIndex in
            tabIndex < referenceIndex
        }
    }

    @discardableResult
    func closeTabsToRight(of sessionID: EditorSession.ID) -> EditorSession? {
        closeTabs(relativeTo: sessionID) { tabIndex, referenceIndex in
            tabIndex > referenceIndex
        }
    }

    @discardableResult
    func goBack() -> EditorSession? {
        guard let entry = navigationHistory.goBack() else { return nil }
        activeSessionID = entry.sessionID
        bypassHistoryForSessionID = entry.sessionID
        return entry.snapshot
    }

    @discardableResult
    func goForward() -> EditorSession? {
        guard let entry = navigationHistory.goForward() else { return nil }
        activeSessionID = entry.sessionID
        bypassHistoryForSessionID = entry.sessionID
        return entry.snapshot
    }

    func closeAll() {
        sessions.removeAll()
        tabs.removeAll()
        activeSessionID = nil
        navigationHistory.clear()
    }

    private func recordActivation(for session: EditorSession) {
        if bypassHistoryForSessionID == session.id {
            bypassHistoryForSessionID = nil
            return
        }
        navigationHistory.recordVisit(session)
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

    @discardableResult
    private func closeTabs(
        relativeTo sessionID: EditorSession.ID,
        selecting shouldCloseIndex: (Int, Int) -> Bool
    ) -> EditorSession? {
        guard let referenceIndex = tabs.firstIndex(where: { $0.sessionID == sessionID }) else {
            return activeSession
        }

        let sessionIDsToClose = tabs.enumerated()
            .filter { shouldCloseIndex($0.offset, referenceIndex) }
            .map { $0.element.sessionID }

        guard !sessionIDsToClose.isEmpty else { return activeSession }

        let closingSet = Set(sessionIDsToClose)
        let wasActiveClosed = activeSessionID.map { closingSet.contains($0) } ?? false

        sessions.removeAll { closingSet.contains($0.id) }
        tabs.removeAll { closingSet.contains($0.sessionID) }
        sessionIDsToClose.forEach { navigationHistory.remove($0) }

        guard !sessions.isEmpty else {
            activeSessionID = nil
            navigationHistory.clear()
            return nil
        }

        syncSessionsToTabOrder()

        guard wasActiveClosed else {
            return activeSession
        }

        if let referenceSession = session(for: sessionID) {
            activeSessionID = referenceSession.id
            recordActivation(for: referenceSession)
            return referenceSession
        }

        let fallbackSession = sessions[0]
        activeSessionID = fallbackSession.id
        recordActivation(for: fallbackSession)
        return fallbackSession
    }
}
