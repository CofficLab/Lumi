import Foundation
import Combine

// MARK: - Editor Workbench State
//
// Phase 4: 编辑器工作台状态。
//
// Workbench 是整个编辑器区域的顶层状态管理者，负责：
// - 管理 EditorGroup 树（支持 split）
// - 追踪 active group
// - 提供全局 session 查找能力

@MainActor
final class EditorWorkbenchState: ObservableObject {
    /// 根 group。如果为空，使用默认 group。
    @Published var rootGroup: EditorGroup

    /// 当前活跃的 group ID。
    @Published var activeGroupID: EditorGroup.ID

    init() {
        let defaultGroup = EditorGroup()
        self.rootGroup = defaultGroup
        self.activeGroupID = defaultGroup.id
    }

    // MARK: - Group Access

    /// 当前活跃的 group。
    var activeGroup: EditorGroup? {
        findGroup(id: activeGroupID)
    }

    /// 所有叶子 group（包含实际编辑器内容的 group）。
    var leafGroups: [EditorGroup] {
        rootGroup.leafGroups()
    }

    /// 查找指定 ID 的 group。
    func findGroup(id: EditorGroup.ID) -> EditorGroup? {
        rootGroup.findSubGroup(id: id)
    }

    /// 根据 session ID 查找它所在的 group。
    func groupContainingSession(sessionID: EditorSession.ID) -> EditorGroup? {
        leafGroups.first { $0.sessions.contains(where: { $0.id == sessionID }) }
    }

    // MARK: - Session Management

    /// 打开或激活一个 session（在当前活跃 group 中）。
    @discardableResult
    func openOrActivate(fileURL: URL?) -> EditorSession? {
        guard let activeGroup else { return nil }
        return activeGroup.openOrActivate(fileURL: fileURL)
    }

    /// 在指定 group 中打开 session。
    @discardableResult
    func openInGroup(fileURL: URL?, groupID: EditorGroup.ID) -> EditorSession? {
        guard let group = findGroup(id: groupID) else { return nil }
        return group.openOrActivate(fileURL: fileURL)
    }

    /// 激活指定 session（并切换到其所在 group）。
    @discardableResult
    func activate(sessionID: EditorSession.ID) -> EditorSession? {
        // 查找 session 所在 group
        if let group = groupContainingSession(sessionID: sessionID) {
            activeGroupID = group.id
            return group.activate(sessionID: sessionID)
        }
        return nil
    }

    /// 关闭 session。
    @discardableResult
    func close(sessionID: EditorSession.ID) -> EditorSession? {
        guard let group = groupContainingSession(sessionID: sessionID) else { return nil }
        return group.close(sessionID: sessionID)
    }

    /// 关闭其他 session。
    @discardableResult
    func closeOthers(keeping sessionID: EditorSession.ID) -> EditorSession? {
        guard let group = groupContainingSession(sessionID: sessionID) else { return nil }
        return group.closeOthers(keeping: sessionID)
    }

    // MARK: - Split Operations

    /// 分割当前活跃 group。
    func splitActiveGroup(_ direction: EditorGroup.SplitDirection) {
        guard let activeGroup, activeGroup.isLeaf else { return }
        activeGroup.split(direction)
        // 新创建的右边/下边 group 成为活跃 group
        if let newGroup = activeGroup.subGroups.last {
            activeGroupID = newGroup.id
        }
    }

    /// 取消分割。
    func unsplitActiveGroup() {
        guard let activeGroup, !activeGroup.isLeaf else { return }
        activeGroup.unsplit()
        // 恢复后，第一个叶子 group 成为活跃
        if let firstLeaf = rootGroup.leafGroups().first {
            activeGroupID = firstLeaf.id
        }
    }

    /// 将当前活跃 group 的 session 移动到另一个 group。
    func moveActiveSessionTo(groupID: EditorGroup.ID) -> Bool {
        guard let activeGroup,
              let sessionID = activeGroup.activeSessionID else { return false }
        let moved = activeGroup.moveSessionToOtherGroup(
            sessionID: sessionID,
            targetGroup: findGroup(id: groupID)
        )
        if moved {
            activeGroupID = groupID
        }
        return moved
    }

    func activateGroup(_ groupID: EditorGroup.ID) {
        guard findGroup(id: groupID) != nil else { return }
        activeGroupID = groupID
    }

    func nextLeafGroup(after groupID: EditorGroup.ID) -> EditorGroup? {
        let groups = leafGroups
        guard let index = groups.firstIndex(where: { $0.id == groupID }), !groups.isEmpty else { return nil }
        return groups[(index + 1) % groups.count]
    }

    func previousLeafGroup(before groupID: EditorGroup.ID) -> EditorGroup? {
        let groups = leafGroups
        guard let index = groups.firstIndex(where: { $0.id == groupID }), !groups.isEmpty else { return nil }
        return groups[(index - 1 + groups.count) % groups.count]
    }

    @discardableResult
    func focusNextGroup() -> EditorGroup? {
        guard let next = nextLeafGroup(after: activeGroupID) else { return nil }
        activeGroupID = next.id
        return next
    }

    @discardableResult
    func focusPreviousGroup() -> EditorGroup? {
        guard let previous = previousLeafGroup(before: activeGroupID) else { return nil }
        activeGroupID = previous.id
        return previous
    }

    @discardableResult
    func moveActiveSessionToNextGroup() -> Bool {
        guard let target = nextLeafGroup(after: activeGroupID) else { return false }
        return moveActiveSessionTo(groupID: target.id)
    }

    @discardableResult
    func moveActiveSessionToPreviousGroup() -> Bool {
        guard let target = previousLeafGroup(before: activeGroupID) else { return false }
        return moveActiveSessionTo(groupID: target.id)
    }

    // MARK: - Sync

    /// 从快照同步活跃 session。
    func syncActiveSession(from snapshot: EditorSession) {
        guard let activeGroup else { return }
        activeGroup.syncActiveSession(from: snapshot)
    }
}
