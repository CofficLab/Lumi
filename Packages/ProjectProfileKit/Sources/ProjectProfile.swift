import Foundation

/// 根据项目文件和依赖推断出的项目高层分类。
public enum ProjectType: String, Codable, Sendable {
    /// 移动端或 Apple 平台应用项目。
    case mobile
    /// Web 应用或前端项目。
    case web
    /// 命令行应用项目。
    case cli
    /// 库、包或 SDK 类型项目。
    case sdk
    /// 通用应用项目。
    case app
    /// 无法可靠推断项目类型。
    case unknown
}

/// 从本地项目目录推断出的技术画像。
public struct ProjectProfile: Codable, Sendable {
    /// 标准化后的项目根目录绝对路径。
    public let projectPath: String
    /// 最可能的主要编程语言。
    public let primaryLanguage: String?
    /// 检测到的框架，例如 SwiftUI、React 或 Vue。
    public let frameworks: [String]
    /// 检测到的包或模块依赖。
    public let dependencies: [String]
    /// 推断出的项目分类。
    public let projectType: ProjectType
    /// 从 README 内容中提取的关键词。
    public let keywords: [String]
    /// 从 README 内容中提取的项目简短描述。
    public let description: String
    /// 可选平台提示，例如 Apple platforms。
    public let platform: String?

    /// 创建项目画像。
    public init(
        projectPath: String,
        primaryLanguage: String?,
        frameworks: [String],
        dependencies: [String],
        projectType: ProjectType,
        keywords: [String],
        description: String,
        platform: String?
    ) {
        self.projectPath = projectPath
        self.primaryLanguage = primaryLanguage
        self.frameworks = frameworks
        self.dependencies = dependencies
        self.projectType = projectType
        self.keywords = keywords
        self.description = description
        self.platform = platform
    }

    /// 用于界面展示的紧凑标题。
    public var shortTitle: String {
        let language = primaryLanguage ?? "Unknown"
        let framework = frameworks.first
        if let framework {
            return "\(language) / \(framework)"
        }
        return language
    }
}
