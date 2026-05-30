import Foundation

/// Agent 规则文档模型
///
/// 表示 .agent/rules 目录中的规则文档
public struct AgentRule: Codable, Identifiable, Sendable {
    /// 文件名（不含扩展名）
    public let id: String

    /// 完整文件名（含扩展名）
    public let filename: String

    /// 文件标题（从文件内容中提取的第一级标题）
    public let title: String

    /// 文件描述（从文件内容中提取的摘要）
    public let description: String

    /// 文件大小（字节）
    public let fileSize: Int64

    /// 创建时间
    public let createdAt: Date

    /// 修改时间
    public let modifiedAt: Date

    /// 完整文件路径
    public let filePath: String

    /// 文件内容
    public let content: String

    /// 文件 URL
    public var fileURL: URL {
        URL(fileURLWithPath: filePath)
    }

    /// 格式化的文件大小
    public var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    /// 格式化的修改时间
    public var formattedModifiedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: modifiedAt, relativeTo: Date())
    }
}

/// Agent 规则元数据（不含内容）
public struct AgentRuleMetadata: Codable, Identifiable, Sendable {
    /// 文件名（不含扩展名）
    public let id: String

    /// 完整文件名（含扩展名）
    public let filename: String

    /// 文件标题
    public let title: String

    /// 文件描述
    public let description: String

    /// 文件大小（字节）
    public let fileSize: Int64

    /// 修改时间
    public let modifiedAt: Date

    /// 完整文件路径
    public let filePath: String

    /// 文件 URL
    public var fileURL: URL {
        URL(fileURLWithPath: filePath)
    }

    /// 格式化的文件大小
    public var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    /// 格式化的修改时间
    public var formattedModifiedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: modifiedAt, relativeTo: Date())
    }
}
