import Foundation

/// 项目模型
struct Project: Identifiable, Codable {
    /// 唯一标识符
    let id: String

    /// 项目名称
    let name: String

    /// 项目描述
    var description: String?

    /// 创建时间
    let createdAt: Date

    /// 更新时间
    var updatedAt: Date

    init(id: String = UUID().uuidString, name: String, description: String? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
