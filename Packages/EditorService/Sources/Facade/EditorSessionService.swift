import Foundation

@MainActor
public final class EditorSessionService {
    private let state: EditorState
    private let sessionStore: EditorSessionStore

    init(state: EditorState, sessionStore: EditorSessionStore) {
        self.state = state
        self.sessionStore = sessionStore
    }

    public var activeSession: EditorSession? { sessionStore.activeSession }
    public var activeSessionID: EditorSession.ID? { sessionStore.activeSessionID }
    var sessions: [EditorSession] { sessionStore.sessions }
    public var tabs: [EditorTab] { sessionStore.tabs }
    var canNavigateBack: Bool { sessionStore.canNavigateBack }
    var canNavigateForward: Bool { sessionStore.canNavigateForward }

    @discardableResult
    public func openFile(at url: URL?) -> EditorSession? {
        guard let url else {
            return sessionStore.openOrActivate(fileURL: nil)
        }

        guard let session = sessionStore.openOrActivate(fileURL: url) else { return nil }
        state.beginPendingContentLoadIfNeeded(for: url)
        return session
    }

    @discardableResult
    public func openFileSessionInBackground(at url: URL) -> EditorSession {
        sessionStore.openSessionWithoutActivating(fileURL: url)
    }

    public func open(at url: URL?) {
        guard let url else { return }

        guard let session = sessionStore.openOrActivate(fileURL: url) else { return }

        let canRestoreImmediately =
            state.currentFileURL == url &&
            state.content != nil &&
            state.focusedTextView != nil

        if canRestoreImmediately {
            state.applySessionRestore(session)
            return
        }

        if state.currentFileURL != url {
            state.loadFile(from: url)
        }
    }

    public func activateAndRestoreSession(id: EditorSession.ID) {
        // 切换 Tab 前保存当前编辑器（遵循自动保存模式语义）
        state.triggerAutoSave(reason: "tab_switch")

        guard let session = sessionStore.activate(sessionID: id) else { return }

        let fileURL = session.fileURL

        let canRestoreImmediately =
            state.currentFileURL == fileURL &&
            state.content != nil &&
            state.focusedTextView != nil

        if canRestoreImmediately {
            state.applySessionRestore(session)
            return
        }

        if state.currentFileURL != fileURL {
            state.loadFile(from: fileURL)
        }
    }

    @discardableResult
    public func closeSession(id: EditorSession.ID) -> EditorSession? {
        sessionStore.close(sessionID: id)
    }

    @discardableResult
    public func closeOtherSessions(keeping id: EditorSession.ID) -> EditorSession? {
        sessionStore.closeOthers(keeping: id)
    }

    @discardableResult
    public func closeTabsToLeft(of id: EditorSession.ID) -> EditorSession? {
        sessionStore.closeTabsToLeft(of: id)
    }

    @discardableResult
    public func closeTabsToRight(of id: EditorSession.ID) -> EditorSession? {
        sessionStore.closeTabsToRight(of: id)
    }

    public func closeAllSessions() {
        sessionStore.closeAll()
    }

    public func cleanupForTeardown() {
        state.cleanupForTeardown()
        sessionStore.closeAll()
    }

    @discardableResult
    public func activateSession(id: EditorSession.ID) -> EditorSession? {
        sessionStore.activate(sessionID: id)
    }

    public func togglePinned(sessionID: EditorSession.ID) {
        sessionStore.togglePinned(sessionID: sessionID)
    }

    @discardableResult
    public func reorderSession(sessionID: EditorSession.ID, before targetID: EditorSession.ID?) -> Bool {
        sessionStore.reorderSession(sessionID: sessionID, before: targetID)
    }

    public func session(for sessionID: EditorSession.ID) -> EditorSession? {
        sessionStore.session(for: sessionID)
    }

    public func recentActivationRank(for sessionID: EditorSession.ID) -> Int? {
        sessionStore.recentActivationRank(for: sessionID)
    }

    @discardableResult
    public func goBack() -> EditorSession? {
        sessionStore.goBack()
    }

    @discardableResult
    public func goForward() -> EditorSession? {
        sessionStore.goForward()
    }

    public func syncActiveSession(from snapshot: EditorSession) {
        sessionStore.syncActiveSession(from: snapshot)
    }
}
