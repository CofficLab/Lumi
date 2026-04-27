import Foundation

struct EditorNavigationHistory {
    private(set) var sessionIDs: [EditorSession.ID] = []
    private(set) var currentIndex: Int?

    var currentSessionID: EditorSession.ID? {
        guard let currentIndex, sessionIDs.indices.contains(currentIndex) else { return nil }
        return sessionIDs[currentIndex]
    }

    var canGoBack: Bool {
        guard let currentIndex else { return false }
        return currentIndex > 0
    }

    var canGoForward: Bool {
        guard let currentIndex else { return false }
        return currentIndex < sessionIDs.count - 1
    }

    mutating func recordVisit(_ sessionID: EditorSession.ID) {
        if currentSessionID == sessionID {
            return
        }

        if let currentIndex, currentIndex < sessionIDs.count - 1 {
            sessionIDs = Array(sessionIDs.prefix(currentIndex + 1))
        }

        sessionIDs.append(sessionID)
        currentIndex = sessionIDs.count - 1
    }

    mutating func goBack() -> EditorSession.ID? {
        guard canGoBack, let currentIndex else { return nil }
        self.currentIndex = currentIndex - 1
        return currentSessionID
    }

    mutating func goForward() -> EditorSession.ID? {
        guard canGoForward, let currentIndex else { return nil }
        self.currentIndex = currentIndex + 1
        return currentSessionID
    }

    mutating func remove(_ sessionID: EditorSession.ID) {
        guard let removedIndex = sessionIDs.firstIndex(of: sessionID) else { return }
        sessionIDs.remove(at: removedIndex)

        guard !sessionIDs.isEmpty else {
            currentIndex = nil
            return
        }

        guard let currentIndex else {
            self.currentIndex = min(removedIndex, sessionIDs.count - 1)
            return
        }

        if removedIndex < currentIndex {
            self.currentIndex = currentIndex - 1
        } else if removedIndex == currentIndex {
            self.currentIndex = min(currentIndex, sessionIDs.count - 1)
        }
    }

    mutating func clear() {
        sessionIDs.removeAll()
        currentIndex = nil
    }
}
