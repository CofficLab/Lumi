import Foundation

// MARK: - Project Info

/// 项目信息（轻量级数据结构）
public struct ProjectInfo: Sendable, Codable {
    public let name: String
    public let path: String
    public let language: String?

    public init(name: String, path: String, language: String? = nil) {
        self.name = name
        self.path = path
        self.language = language
    }
}

// MARK: - Project Capability Protocol

/// 项目管理能力协议
///
/// 定义 LumiCore 需要的项目管理功能，由 LumiCoreProject 实现。
@MainActor
public protocol ProjectProviding: ObservableObject {
    /// 当前打开的项目
    var currentProject: ProjectInfo? { get }

    /// 所有项目列表
    var projects: [ProjectInfo] { get }

    /// 打开项目
    func openProject(at path: String) async throws

    /// 关闭当前项目
    func closeProject() async

    /// 刷新项目列表
    func refreshProjects() async throws
}