import Foundation
import ProviderProject

/// Projects 插件需要的最小项目能力边界。
///
/// ViewModel 通过该协议读写项目列表与当前项目，不直接持有
/// `ProjectProviding` 具体类型；Provider 的解析与适配由插件入口完成。
@MainActor
protocol ProjectsProjectCapability: AnyObject {
    /// 所有项目列表。
    var projects: [ProjectInfo] { get }

    /// 当前打开的项目。
    var currentProject: ProjectInfo? { get }

    /// 同步应用当前维护的完整项目列表。
    func synchronizeProjects(_ projects: [ProjectInfo])

    /// 打开项目。
    func openProject(at path: String, reason: ProjectChangeReason) async throws

    /// 关闭当前项目。
    func closeProject(reason: ProjectChangeReason) async
}

/// 将内核的 `ProjectProviding` 收窄为 Projects 插件的项目能力。
@MainActor
final class ProjectsProjectCapabilityAdapter: ProjectsProjectCapability {
    private let project: any ProjectProviding

    init(project: any ProjectProviding) {
        self.project = project
    }

    var projects: [ProjectInfo] { project.projects }

    var currentProject: ProjectInfo? { project.currentProject }

    func synchronizeProjects(_ projects: [ProjectInfo]) {
        project.synchronizeProjects(projects)
    }

    func openProject(at path: String, reason: ProjectChangeReason) async throws {
        try await project.openProject(at: path, reason: reason)
    }

    func closeProject(reason: ProjectChangeReason) async {
        await project.closeProject(reason: reason)
    }
}
