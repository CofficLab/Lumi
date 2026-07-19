import Foundation
import LumiKernel

/// 项目服务实现
@MainActor
public final class ProjectService: ProjectProviding {

    // MARK: - Published State

    @Published public private(set) var currentProject: ProjectInfo?
    @Published public private(set) var projects: [ProjectInfo] = []

    // MARK: - Initialization

    public init() {
        // 初始状态：无项目
    }

    // MARK: - ProjectProviding

    public func openProject(at path: String) async throws {
        // 简单实现：创建项目信息并设置
        let url = URL(fileURLWithPath: path)
        let name = url.lastPathComponent
        let project = ProjectInfo(name: name, path: path)
        currentProject = project

        // 如果不在列表中，添加到列表
        if !projects.contains(where: { $0.path == path }) {
            projects.append(project)
        }
    }

    public func closeProject() async {
        currentProject = nil
    }

    public func refreshProjects() async throws {
        // 简单实现：无操作
        // 完整实现会扫描最近项目目录
    }
}