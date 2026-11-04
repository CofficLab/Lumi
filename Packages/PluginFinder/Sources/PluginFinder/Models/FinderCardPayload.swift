import Foundation

/// 卡片的结构化载荷。
///
/// 这份数据随消息一起落库（JSON 化后写入 `Message.metadata`），
/// 因此渲染器重启后仍能还原出完整的卡片，而不必依赖内存里的临时状态。
public struct FinderCardPayload: Codable, Sendable, Equatable {
    /// 卡片标题。为空时渲染器回退到文件夹名。
    public let title: String
    /// 卡片副标题。为空时不渲染描述行。
    public let description: String
    /// 要在 Finder 中打开的文件夹绝对路径。
    public let path: String
    /// 按钮标题。为空时渲染器使用本地化默认值。
    public let actionTitle: String

    public init(
        title: String = "",
        description: String = "",
        path: String,
        actionTitle: String = ""
    ) {
        self.title = title
        self.description = description
        self.path = path
        self.actionTitle = actionTitle
    }

    /// 标题回退：优先用标题，其次用文件夹名，最后用路径本身。
    public var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let folderName = (path as NSString).lastPathComponent
        return folderName.isEmpty ? path : folderName
    }

    /// 描述回退：去掉首尾空白后为空则视为无描述。
    public var displayDescription: String? {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// 按钮标题回退：为空时由渲染器填入本地化默认值。
    public var displayActionTitle: String? {
        let trimmed = actionTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
