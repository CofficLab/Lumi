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
        // 同一 Session 在历史里可能有多个非相邻条目（A → B → A），关闭标签时
        // 必须全部删除，否则后退/前进仍会选中已不存在的 Session。
        let removedIndices = entries.indices.filter { entries[$0].sessionID == sessionID }
        guard !removedIndices.isEmpty else { return }

        let previousIndex = currentIndex
        entries.removeAll { $0.sessionID == sessionID }

        guard !entries.isEmpty else {
            currentIndex = nil
            return
        }

        guard let previousIndex else {
            currentIndex = min(removedIndices[0], entries.count - 1)
            return
        }

        let removedBeforeCurrent = removedIndices.filter { $0 < previousIndex }.count
        if removedIndices.contains(previousIndex) {
            // 当前项也被删除：停在原位置（越界则回到最后一项）。
            currentIndex = min(previousIndex - removedBeforeCurrent, entries.count - 1)
        } else {
            currentIndex = previousIndex - removedBeforeCurrent
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
