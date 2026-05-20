import Foundation

/// 窗口持久化记录
/// 插件内部用于磁盘读写的 Codable 结构，内核不感知此类型。
///
/// 注意：窗口级项目路径（projectPath）由 `RecentProjectsPlugin` 负责持久化。
struct WindowPersistenceRecord: Codable {
    let windowId: UUID
    let conversationId: UUID?
    let activePanel: String?
    let editorState: WindowEditorState?
    let sidebarVisibility: Bool?
    let createdAt: Date?
}
