import Foundation

@MainActor
struct EditorNavigationHistory {
    struct Entry {
        let sessionID: EditorSession.ID
        var snapshot: EditorSession
    }

    private(set) var entries: [Entry] = []
    private(set) var currentIndex: Int?
    private let maximumDepth: Int

    init(maximumDepth: Int = 100) {
        self.maximumDepth = maximumDepth
    }

    var sessionIDs: [EditorSession.ID] {
        entries.map(\.sessionID)
    }

    var currentEntry: Entry? {
        guard let currentIndex, entries.indices.contains(currentIndex) else { return nil }
        return entries[currentIndex]
    }

    var currentSessionID: EditorSession.ID? {
        currentEntry?.sessionID
    }

    var canGoBack: Bool {
        guard let currentIndex else { return false }
        return currentIndex > 0
    }

    var canGoForward: Bool {
        guard let currentIndex else { return false }
        return currentIndex < entries.count - 1
    }

    mutating func recordVisit(_ snapshot: EditorSession) {
        if currentEntry?.sessionID == snapshot.id {
            replaceCurrent(with: snapshot)
            return
        }

        if let currentIndex, currentIndex < entries.count - 1 {
            entries = Array(entries.prefix(currentIndex + 1))
        }

        entries.append(Entry(sessionID: snapshot.id, snapshot: EditorSession(snapshot: snapshot)))
        trimIfNeeded()
        currentIndex = entries.count - 1
    }

    mutating func replaceCurrent(with snapshot: EditorSession) {
        guard let currentIndex, entries.indices.contains(currentIndex) else { return }
        entries[currentIndex] = Entry(sessionID: snapshot.id, snapshot: EditorSession(snapshot: snapshot))
    }

    mutating func goBack() -> Entry? {
        guard canGoBack, let currentIndex else { return nil }
        self.currentIndex = currentIndex - 1
        return currentEntry
    }

    mutating func goForward() -> Entry? {
        guard canGoForward, let currentIndex else { return nil }
        self.currentIndex = currentIndex + 1
        return currentEntry
    }

    mutating func remove(_ sessionID: EditorSession.ID) {
        guard let removedIndex = entries.firstIndex(where: { $0.sessionID == sessionID }) else { return }
        entries.remove(at: removedIndex)

        guard !entries.isEmpty else {
            currentIndex = nil
            return
        }

        guard let currentIndex else {
            self.currentIndex = min(removedIndex, entries.count - 1)
            return
        }

        if removedIndex < currentIndex {
            self.currentIndex = currentIndex - 1
        } else if removedIndex == currentIndex {
            self.currentIndex = min(currentIndex, entries.count - 1)
        }
    }

    mutating func clear() {
        entries.removeAll()
        currentIndex = nil
    }

    private mutating func trimIfNeeded() {
        guard entries.count > maximumDepth else { return }
        let overflow = entries.count - maximumDepth
        entries.removeFirst(overflow)
        if let currentIndex {
            self.currentIndex = max(currentIndex - overflow, 0)
        }
    }
}
