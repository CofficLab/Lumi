import Foundation

/// 记忆条目
///
/// 对应磁盘上的一条记忆 Markdown 文件，包含 frontmatter 元数据和正文内容。
struct MemoryItem: Codable, Identifiable, Sendable {
    /// 唯一标识（文件名，不含 .md 后缀）
    let id: String
    /// 文件名（含 .md）
    let filename: String
    /// 记忆类型
    let type: MemoryType
    /// 简短名称（frontmatter 中的 name）
    let name: String
    /// 描述（frontmatter 中的 description，用于判断相关性）
    let description: String
    /// 记忆正文
    let content: String
    /// 创建时间
    let createdAt: Date
    /// 最后更新时间
    let updatedAt: Date
    /// 文件绝对路径
    let filePath: String

    /// 记忆年龄（天数）
    var ageInDays: Int {
        Int(Date().timeIntervalSince(updatedAt) / 86400)
    }

    /// 是否已过时（超过配置的阈值）
    var isStale: Bool {
        ageInDays > MemoryPluginLocalStore.shared.staleThresholdDays
    }

    /// 格式化后的显示文本（用于注入提示词）
    func formattedSummary() -> String {
        "[\(type.rawValue)] \(name) — \(description)"
    }

    /// 完整格式化内容（含时效提醒）
    func formattedContent() -> String {
        var parts: [String] = []
        parts.append("**\(formattedSummary())**")
        parts.append("")
        parts.append(content)
        if isStale {
            parts.append("")
            parts.append("> ⚠️ 此记忆创建于 \(ageInDays) 天前，可能已过时。使用前请验证。")
        }
        return parts.joined(separator: "\n")
    }
}
