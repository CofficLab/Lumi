import Combine
import Foundation
import ProviderConversation
import ProviderMessage

extension ConversationManager {
    // MARK: - Project Switch → Migrate Empty Conversations

    /// 订阅项目 Provider 的变更，在当前项目切换时把所有空对话迁移到新项目。
    ///
    /// `objectWillChange` 在 `ProjectProviding` 的任何 `@Published` 状态变化时都会触发，
    /// 因此这里通过比较切换前后的 `currentProject.path` 来判断是否为真正的
    /// 「当前项目切换」，避免误迁移。`currentProject.path` 已由宿主标准化，
    /// 与 `createConversation` 写入的路径一致。
    func observeProjectChanges() {
        guard let project else { return }
        previousProjectPath = project.currentProject?.path

        projectChangeCancellable = project.objectWillChange
            .map { _ in () }
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                let newProjectPath = project.currentProject?.path
                guard newProjectPath != self.previousProjectPath else { return }

                // 关闭项目（新路径为 nil）：仅更新缓存，不迁移空对话。
                let oldPath = self.previousProjectPath
                self.previousProjectPath = newProjectPath
                guard let newProjectPath else { return }

                self.reassignEmptyConversations(to: newProjectPath, from: oldPath)
            }
    }

    /// 把所有「没有任何消息」的空对话关联项目更新为 `projectPath`。
    ///
    /// 空判定以「当前消息存储中是否存在消息」为准：逐会话查询消息数，取为 0 的对话。
    /// 计算在主线程进行（v2 `MessageManaging` 为内存同步实现），SQLite 写库 hop 到 actor。
    private func reassignEmptyConversations(to projectPath: String, from oldProjectPath: String?) {
        let messageManager = self.messageManager
        let snapshot = conversations
        let store = store

        Task { [weak self, messageManager, snapshot, store, projectPath, oldProjectPath] in
            // 空对话 = 快照中「没有任何消息」的对话。
            let emptyIDs = snapshot.filter { conversation in
                (messageManager?.messageCount(for: conversation.id) ?? 0) == 0
            }.map(\.id)

            guard !emptyIDs.isEmpty else { return }
            await store?.updateProjectPath(for: emptyIDs, projectPath: projectPath)

            guard let self else { return }
            var updated = false
            let idSet = Set(emptyIDs)
            for index in self.conversations.indices where idSet.contains(self.conversations[index].id) {
                self.conversations[index].projectPath = projectPath
                updated = true
            }
            guard updated else { return }
            self.conversations = self.conversations
            self.notifyConversationsChanged()
            if Self.verbose {
                Self.logger.info("\(Self.t)项目切换 \(oldProjectPath ?? "nil") → \(projectPath)：迁移 \(emptyIDs.count) 个空对话")
            }
        }
    }
}
