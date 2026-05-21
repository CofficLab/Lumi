import Foundation

/// 窗口持久化记录（仅用于写入磁盘）
struct WindowPersistenceRecord: Codable {
    let windowId: UUID
    let conversationId: UUID?
    let projectPath: String?
    /// 编辑器已打开文件路径
    let editorOpenFilePaths: [String]?
    /// 编辑器当前活跃文件路径
    let editorActiveFilePath: String?
    let sidebarVisibility: Bool?
    let createdAt: Date?
}
