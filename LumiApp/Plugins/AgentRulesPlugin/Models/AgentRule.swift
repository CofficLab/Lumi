import Foundation

/// Agent 规则文档模型
///
/// 表示 .agent/rules 目录中的规则文档
struct AgentRule: Codable, Identifiable, Sendable {
    /// 文件名（不含扩展名）
    let id: String

    /// 完整文件名（含扩展名）
    let filename: String

    /// 文件标题（从文件内容中提取的第一级标题）
    let title: String

    /// 文件描述（从文件内容中提取的摘要）
    let description: String

    /// 文件大小（字节）
    let fileSize: Int64

    /// 创建时间
    let createdAt: Date

    /// 修改时间
    let modifiedAt: Date

    /// 完整文件路径
    let filePath: String

    /// 文件内容
    let content: String

    /// 文件 URL
    var fileURL: URL {
        URL(fileURLWithPath: filePath)
    }

    /// 格式化的文件大小
    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    /// 格式化的修改时间
    var formattedModifiedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: modifiedAt, relativeTo: Date())
    }
}

/// Agent 规则元数据（不含内容）
struct AgentRuleMetadata: Codable, Identifiable, Sendable {
    /// 文件名（不含扩展名）
    let id: String

    /// 完整文件名（含扩展名）
    let filename: String

    /// 文件标题
    let title: String

    /// 文件描述
    let description: String

    /// 文件大小（字节）
    let fileSize: Int64

    /// 修改时间
    let modifiedAt: Date

    /// 完整文件路径
    let filePath: String

    /// 文件 URL
    var fileURL: URL {
        URL(fileURLWithPath: filePath)
    }

    /// 格式化的文件大小
    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    /// 格式化的修改时间
    var formattedModifiedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: modifiedAt, relativeTo: Date())
    }
}
