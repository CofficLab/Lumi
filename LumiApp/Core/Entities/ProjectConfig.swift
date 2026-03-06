import Foundation

/// 项目配置模型
public struct ProjectConfig: Codable, Identifiable, Equatable {
    public let id: UUID
    public let projectPath: String
    public var providerId: String
    public var model: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(projectPath: String, providerId: String = "anthropic", model: String = "") {
        self.id = UUID()
        self.projectPath = projectPath
        self.providerId = providerId
        self.model = model
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// 获取项目名称
    public var projectName: String {
        URL(fileURLWithPath: projectPath).lastPathComponent
    }
}
