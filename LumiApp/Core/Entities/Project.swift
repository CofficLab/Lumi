import Foundation

/// 项目模型
struct Project: Identifiable, Codable {
    /// 唯一标识符
    let id: String

    /// 项目名称
    let name: String

    init(id: String = UUID().uuidString, name: String) {
        self.id = id
        self.name = name
    }
}
