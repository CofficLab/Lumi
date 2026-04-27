import Foundation

// MARK: - Editor Group
//
// Phase 4: 编辑器分栏组。
//
// 一个 EditorGroup 代表一个编辑分栏，包含一组 tab（sessions）和一个当前活跃的 session。
// 多个 EditorGroup 可以水平或垂直排列，实现 split editor 效果。
//
// 设计：
//   - 每个 group 独立管理自己的 tab 列表和活跃 session
//   - group 可以嵌套（split 方向）
//   - 全局只有一个 active group

/// 编辑器分栏组。
///
/// 管理一组 tab 和当前活跃 session。
/// 多个 group 可以水平或垂直分割显示。
@MainActor
final class EditorGroup: ObservableObject, Identifiable {
    let id: UUID

    /// 当前活跃 session 的 ID。
    @Published var activeSessionID: EditorSession.ID?

    /// 该 group 中的所有 sessions。
    @Published private(set) var sessions: [EditorSession] = []

    /// 该 group 中的 tabs。
    @Published var tabs: [EditorTab] = []

    /// 分栏方向。
    enum SplitDirection: Equatable, Sendable {
        case horizontal  // 左右分割
        case vertical    // 上下分割
    }

    /// 子 group 的分栏方向。如果为 nil，表示没有子 group（叶子 group）。
    @Published var splitDirection: SplitDirection = .horizontal

    /// 子 groups。如果为空，表示这是一个叶子 group（包含实际的编辑器内容）。
    @Published private(set) var subGroups: [EditorGroup] = []

    var isActive: Bool = false

    /// 当前活跃的 session。
    var activeSession: EditorSession? {
        guard let activeSessionID else { return nil }
        return sessions.first(where: { $0.id == activeSessionID })
    }

    /// 是否有内容（session 或子 group）。
    var isEmpty: Bool {
        sessions.isEmpty && subGroups.isEmpty
    }

    /// 是否为叶子 group（没有子 group）。
    var isLeaf: Bool {
        subGroups.isEmpty
    }

    init(id: UUID = UUID()) {
        self.id = id
    }

    // MARK: - Session Management

    /// 打开或激活一个 session。
    @discardableResult
    func openOrActivate(fileURL: URL?) -> EditorSession? {
        guard let fileURL else { return nil }

        // 检查是否已有该 session
        if let existing = sessions.first(where: { $0.fileURL == fileURL }) {
            activeSessionID = existing.id
            return existing
        }

        // 创建新 session
        let session = EditorSession(fileURL: fileURL)
        sessions.append(session)
        tabs.append(EditorTab(sessionID: session.id, fileURL: fileURL))
        activeSessionID = session.id
        return session
    }

    /// 激活指定 session。
    @discardableResult
    func activate(sessionID: EditorSession.ID) -> EditorSession? {
        guard sessions.contains(where: { $0.id == sessionID }) else { return nil }
        activeSessionID = sessionID
        return sessions.first(where: { $0.id == sessionID })
    }

    /// 获取指定 session。
    func session(for sessionID: EditorSession.ID) -> EditorSession? {
        sessions.first(where: { $0.id == sessionID })
    }

    /// 关闭指定 session。
    @discardableResult
    func close(sessionID: EditorSession.ID) -> EditorSession? {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else {
            return activeSession
        }

        let wasActive = activeSessionID == sessionID
        sessions.remove(at: index)
        tabs.removeAll(where: { $0.sessionID == sessionID })

        if wasActive {
            let nextIndex = min(index, max(sessions.count - 1, 0))
            if !sessions.isEmpty {
                activeSessionID = sessions[nextIndex].id
                return sessions[nextIndex]
            } else {
                activeSessionID = nil
                return nil
            }
        }

        return activeSession
    }

    /// 关闭其他 session，保留指定的 session。
    @discardableResult
    func closeOthers(keeping sessionID: EditorSession.ID) -> EditorSession? {
        guard let kept = sessions.first(where: { $0.id == sessionID }) else { return activeSession }
        sessions = [kept]
        tabs = tabs.filter { $0.sessionID == sessionID }
        activeSessionID = kept.id
        return kept
    }

    /// 关闭所有 session。
    func closeAll() {
        sessions.removeAll()
        tabs.removeAll()
        activeSessionID = nil
    }

    // MARK: - Split Management

    /// 分割当前 group，创建两个子 group。
    func split(_ direction: SplitDirection) {
        guard subGroups.isEmpty else { return }

        let left = EditorGroup()
        let right = EditorGroup()

        // 将当前 session 移到第一个子 group
        left.sessions = sessions
        left.tabs = tabs
        left.activeSessionID = activeSessionID

        subGroups = [left, right]
        splitDirection = direction

        // 清理当前 level 的 session
        sessions.removeAll()
        tabs.removeAll()
        activeSessionID = nil
    }

    /// 合并子 group，恢复为单个 group。
    func unsplit() {
        guard !subGroups.isEmpty else { return }

        // 收集所有子 group 的 session
        var allSessions: [EditorSession] = []
        var allTabs: [EditorTab] = []
        var firstActiveID: EditorSession.ID?

        for group in subGroups {
            allSessions.append(contentsOf: group.sessions)
            allTabs.append(contentsOf: group.tabs)
            if firstActiveID == nil {
                firstActiveID = group.activeSessionID
            }
        }

        subGroups.removeAll()
        sessions = allSessions
        tabs = allTabs
        activeSessionID = firstActiveID
    }

    /// 将 session 移动到另一个 group。
    func moveSessionToOtherGroup(
        sessionID: EditorSession.ID,
        targetGroupID: EditorGroup.ID
    ) -> Bool {
        guard let sessionIndex = sessions.firstIndex(where: { $0.id == sessionID }),
              let session = sessions[safe: sessionIndex] else { return false }

        // 找到目标 group（在当前 group 的子 group 中查找）
        guard let targetGroup = findSubGroup(id: targetGroupID) else { return false }

        sessions.remove(at: sessionIndex)
        tabs.removeAll(where: { $0.sessionID == sessionID })

        // 如果移动的是活跃 session，切换到下一个
        if activeSessionID == sessionID {
            let nextIndex = min(sessionIndex, max(sessions.count - 1, 0))
            activeSessionID = sessions.isEmpty ? nil : sessions[nextIndex].id
        }

        // 添加到目标 group
        targetGroup.sessions.append(session)
        targetGroup.tabs.append(EditorTab(sessionID: session.id, fileURL: session.fileURL))
        targetGroup.activeSessionID = session.id

        return true
    }

    /// 在子 group 树中查找指定 ID 的 group。
    func findSubGroup(id: EditorGroup.ID) -> EditorGroup? {
        if self.id == id { return self }
        for subGroup in subGroups {
            if let found = subGroup.findSubGroup(id: id) {
                return found
            }
        }
        return nil
    }

    /// 获取所有叶子 group。
    func leafGroups() -> [EditorGroup] {
        if isLeaf { return [self] }
        return subGroups.flatMap { $0.leafGroups() }
    }

    /// 同步 session 快照。
    func syncActiveSession(from snapshot: EditorSession) {
        guard let fileURL = snapshot.fileURL else { return }

        let session = openOrActivate(fileURL: fileURL) ?? EditorSession(fileURL: fileURL)
        session.applySnapshot(from: snapshot)
        updateTab(for: session)
        activeSessionID = session.id
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
    }
}

// MARK: - Array Safe Access

private extension Array {
    subscript(safe index: Index) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
