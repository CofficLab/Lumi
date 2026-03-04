import Foundation

/// 项目文件树节点数据模型
struct FileTreeNode: Identifiable, Hashable {
    /// 唯一标识符
    let id = UUID()

    /// 文件/文件夹名称
    let name: String

    /// 文件 URL
    let url: URL

    /// 是否为文件夹
    let isDirectory: Bool

    /// 是否展开（仅对文件夹有效）
    var isExpanded: Bool

    /// 子节点列表（仅对文件夹有效）
    var children: [FileTreeNode]?

    /// 哈希值（用于 Hashable 协议）
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(url)
    }

    /// 相等比较（用于 Hashable 协议）
    static func == (lhs: FileTreeNode, rhs: FileTreeNode) -> Bool {
        lhs.id == rhs.id
    }
}
