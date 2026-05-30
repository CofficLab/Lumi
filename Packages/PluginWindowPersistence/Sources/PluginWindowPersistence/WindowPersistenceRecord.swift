import Foundation

/// 窗口持久化记录（仅用于写入磁盘）
public struct WindowPersistenceRecord: Codable {
    public let windowId: UUID
    public let conversationId: UUID?
    public let projectPath: String?
    /// 编辑器已打开文件路径
    public let editorOpenFilePaths: [String]?
    /// 编辑器当前活跃文件路径
    public let editorActiveFilePath: String?
    public let sidebarVisibility: Bool?
    public let createdAt: Date?

    public init(
        windowId: UUID,
        conversationId: UUID?,
        projectPath: String?,
        editorOpenFilePaths: [String]?,
        editorActiveFilePath: String?,
        sidebarVisibility: Bool?,
        createdAt: Date?
    ) {
        self.windowId = windowId
        self.conversationId = conversationId
        self.projectPath = projectPath
        self.editorOpenFilePaths = editorOpenFilePaths
        self.editorActiveFilePath = editorActiveFilePath
        self.sidebarVisibility = sidebarVisibility
        self.createdAt = createdAt
    }
}
