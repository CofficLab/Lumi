import Foundation

/// 窗口持久化记录（仅用于写入磁盘）
struct WindowPersistenceRecord: Codable {
    let windowId: UUID
    let conversationId: UUID?
    let projectPath: String?
    let activePanel: String?
    let editorState: WindowEditorState?
    let sidebarVisibility: Bool?
    let createdAt: Date?
}
